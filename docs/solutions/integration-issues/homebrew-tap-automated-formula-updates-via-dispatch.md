---
title: "Automated Homebrew formula updates via repository_dispatch with brew test-bot CI"
category: integration-issues
date: 2026-03-17
tags:
  - homebrew
  - github-actions
  - repository-dispatch
  - brew-test-bot
  - ci-cd
  - expression-injection
  - security-hardening
  - cross-repo-automation
  - rust-cli
  - source-build-formula
  - setup-homebrew
  - symlink
  - git-credentials
components:
  - .github/workflows/update-formula.yml
  - .github/workflows/tests.yml
  - Formula/xurl-rs.rb
  - Formula/bird.rb
severity: high
symptoms:
  - "Formula sha256 mismatch after new release — brew install fails with checksum error"
  - "brew audit silently passes when given a file path instead of formula name, masking real errors"
  - "CI uses actions/checkout instead of Homebrew/actions/setup-homebrew, causing tap resolution failures"
  - "curl --fail discards HTTP error body, making tarball download failures hard to diagnose"
  - "Untrusted client_payload values interpolated directly in shell commands, enabling expression injection"
  - "Conditional insert-or-update sed logic for sha256 is fragile when formula lacks a pre-existing placeholder"
  - "Formula file edits silently reverted after setup-homebrew step replaces checkout directory with symlink"
  - "git push fails with 'The current branch main has no upstream branch' in symlinked tap directory"
  - "git push origin main fails with 'Authentication failed' because setup-homebrew destroyed checkout credentials"
---

# Automated Homebrew Formula Updates via repository_dispatch

## Problem

Manual Homebrew formula updates after each release of xurl-rs or bird are error-prone, easy to
forget, and don't scale. Each release requires downloading the tarball, computing the sha256, editing
the formula, and pushing -- a process ripe for human error. The initial automation attempt also
contained several security and correctness issues that had to be discovered and fixed.

## Root Cause

There is no built-in mechanism for Homebrew taps to receive updates when an upstream tool publishes a
new release. The solution requires cross-repo CI/CD automation (repository_dispatch), but GitHub
Actions has non-obvious security pitfalls (expression injection), Homebrew has underdocumented CI
constraints (disabled path-based audit, required setup-homebrew action), and curl's default error
handling silently masks download failures.

Additionally, `Homebrew/actions/setup-homebrew@main` replaces the runner's `$GITHUB_WORKSPACE`
directory with a symlink to Homebrew's canonical tap path
(`$(brew --repository)/Library/Taps/<owner>/homebrew-tap`). This single side effect causes three
cascading failures:

1. **File mutations are lost.** Any file modifications made *before* `setup-homebrew` are silently
   reverted when the symlink replaces the directory.
2. **Git upstream tracking is absent.** The symlinked tap directory is a shallow clone with no
   remote tracking branches, so bare `git push` fails.
3. **Git credentials are destroyed.** `actions/checkout` injects an `Authorization` extraheader
   into `.git/config`; the symlink replacement destroys it.

## Solution

### 1. Pre-seed formulas with v0.0.0 placeholder

Ensure every formula has a `sha256` line from creation so the update workflow uses unconditional
`sed` replacement instead of conditional insert-or-update logic.

**Critical: use `v0.0.0` as the placeholder version, not the real first release version.** If the
pre-seeded URL already matches the first release (e.g., `v0.1.0`), the dispatch only updates the
sha256. `brew test-bot` rejects this: "stable sha256 changed without the url/version also changing."
Using `v0.0.0` ensures the first dispatch changes both URL and sha256.

```ruby
url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v0.0.0.tar.gz"
sha256 "0000000000000000000000000000000000000000000000000000000000000000"
```

### 2. Create update-formula.yml with security hardening

Key patterns:

```yaml
# Job-level env prevents expression injection (CRITICAL)
env:
  FORMULA: ${{ github.event.client_payload.formula || inputs.formula }}
  VERSION: ${{ github.event.client_payload.version || inputs.version }}
  REPO: ${{ github.event.client_payload.repo || inputs.repo }}
```

```bash
# Input validation before shell use
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Invalid version format: ${VERSION}"
  exit 1
fi
```

```bash
# --fail-with-body preserves error diagnostics (not --fail)
SHA=$(curl --fail-with-body -sL "$TARBALL_URL" | sha256sum | awk '{print $1}')
```

```bash
# Two unconditional sed commands (sha256 pre-seeded)
sed -i "s|url \"...\"|url \"...\"|" "$F"
sed -i "s|sha256 \".*\"|sha256 \"${SHA256}\"|" "$F"
```

### 3. Create tests.yml using official brew test-bot patterns

```yaml
# MUST use setup-homebrew, NOT actions/checkout
- uses: Homebrew/actions/setup-homebrew@main

# --only-formulae requires PR git diff context
- run: brew test-bot --only-formulae
  if: github.event_name == 'pull_request'
```

### 4. Dispatch from tool repo's release workflow

```bash
# Use gh api, not raw curl
gh api repos/brettdavies/homebrew-tap/dispatches \
  --method POST \
  -f event_type=update-formula \
  -f 'client_payload[formula]=xurl-rs' \
  -f "client_payload[version]=${VERSION}" \
  -f 'client_payload[repo]=brettdavies/xurl-rs'
```

### 5. Handle setup-homebrew symlink side effects

`setup-homebrew` replaces the checkout directory with a symlink, destroying file edits, git
credentials, and tracking branches. Three fixes were required (PRs #7, #9, #11):

**Fix 1 -- Reorder steps so setup-homebrew runs before file modifications:**

```yaml
steps:
  - uses: actions/checkout@v6
    with:
      token: ${{ secrets.HOMEBREW_TAP_TOKEN }}

  - name: Validate inputs
    run: ...

  # setup-homebrew MUST run before any file modifications
  - name: Set up Homebrew
    uses: Homebrew/actions/setup-homebrew@main

  # All edits happen AFTER the symlink replacement
  - name: Download tarball and compute SHA256
    run: ...
  - name: Update formula
    run: sed -i "..." "Formula/${FORMULA}.rb"
```

**Fix 2 -- Use explicit remote and branch in git push:**

```bash
# Before (fails: no upstream branch in symlinked directory)
git push

# After
git push origin main
```

**Fix 3 -- Re-configure git credentials after setup-homebrew:**

```yaml
- name: Commit and push
  env:
    HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    # Re-authenticate — setup-homebrew destroyed checkout credentials
    git remote set-url origin "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${{ github.repository }}.git"
    git add "Formula/${FORMULA}.rb"
    git diff --cached --quiet && echo "No changes" && exit 0
    git commit -m "chore(${FORMULA}): bump to v${VERSION}"
    git push origin main
```

**Final working step order:**

1. `actions/checkout` (with PAT token)
2. Validate inputs
3. `Homebrew/actions/setup-homebrew` -- destroys checkout dir, replaces with symlink
4. Download tarball + compute SHA256
5. sed-edit formula
6. `brew audit`
7. Re-configure git remote URL with PAT
8. git add, commit, `push origin main`

## What Didn't Work

- **Inline `${{ github.event.client_payload.* }}` in `run:` blocks** -- expression injection
  vulnerability. Attacker-controlled payloads can break out of string context and execute arbitrary
  commands. Fixed by moving to job-level `env:`.

- **`brew audit Formula/xurl-rs.rb` (path-based)** -- silently disabled by Homebrew. Exits 0,
  masking real errors. Must use `brew test-bot --only-tap-syntax` or audit by formula name.

- **`actions/checkout` for Homebrew CI** -- doesn't register the repo as a tap. `brew` commands
  operate against the published default branch, not the PR/push code. Must use
  `Homebrew/actions/setup-homebrew@main`.

- **`curl --fail`** -- discards the HTTP error body. A 404 gives only a generic error message with
  no context. `--fail-with-body` (curl 7.76+) preserves the response for diagnostics.

- **Conditional sha256 insert-or-update logic** -- fragile and doubles the test surface. Pre-seeding
  a placeholder makes updates a single unconditional `sed` substitution.

- **Raw `curl` for repository_dispatch** -- requires manual token header management. `gh api`
  handles auth automatically and gives better error output.

- **Placing `setup-homebrew` after file edits** -- the symlink replacement silently reverted all
  formula modifications. The workflow reported "No changes" and exited 0, making the failure appear
  successful. This was the most insidious issue because there was no error signal.

- **Using bare `git push` after `setup-homebrew`** -- the symlinked directory has no upstream
  tracking configured. Error: `The current branch main has no upstream branch`. Must use
  `git push origin main`.

- **Relying on `actions/checkout` credentials to survive `setup-homebrew`** -- the checkout action's
  credential injection (via `http.extraheader` in `.git/config`) is tied to the physical checkout
  directory. The symlink replacement destroys those credentials. The PAT must be re-injected via
  `git remote set-url`.

- **Not anticipating cascading failures from the symlink** -- each fix was correct in isolation but
  only revealed the next failure in the chain. The three consequences (lost edits, lost tracking,
  lost credentials) manifest at different workflow stages. End-to-end testing after each fix was
  essential.

## Prevention Strategies

### Expression Injection

- **Always assign untrusted data to `env:` at job or step level.** Never interpolate
  `${{ github.event.client_payload.* }}`, `${{ inputs.* }}`, or
  `${{ github.event.issue.title }}` inside `run:` blocks.
- **Validate format before use.** Even after safe `env:` assignment, reject unexpected content with
  regex guards.
- **Detect existing violations:**

  ```bash
  rg '\$\{\{.*github\.event\.(client_payload|inputs|issue|pull_request)\.' --glob '*.yml' .github/workflows/
  ```

### Homebrew CI

- **Always use `Homebrew/actions/setup-homebrew@main`** as the first step in any workflow that runs
  `brew` commands.
- **Never call `brew audit` by file path.** Use formula name or
  `brew test-bot --only-tap-syntax`.
- **Gate `--only-formulae` to PRs only** (`if: github.event_name == 'pull_request'`).
- **Derive CI workflows from `brew tap-new` output**, not from scratch.

### setup-homebrew Symlink

- **Run `setup-homebrew` immediately after `actions/checkout`**, before any file reads, edits, or
  git operations. The symlink replacement is silent and total -- there is no warning and no way to
  recover state from the original directory.
- **Re-configure the remote URL with a PAT after `setup-homebrew`.** Use
  `git remote set-url origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"`. This is
  not optional.
- **Always use `git push origin <branch>` explicitly.** The symlinked directory never has an
  upstream tracking branch.
- **Set `git config user.name` and `user.email` after `setup-homebrew`**, not before -- the config
  is destroyed with the original checkout.
- **If CI silently produces "no changes" or fails on push, check step ordering first.** The symlink
  replacement is the most common root cause and the hardest to diagnose because it fails silently.

### curl Error Handling

- **Always use `--fail-with-body`** instead of `--fail` for HTTP downloads.
- Without either flag, curl silently succeeds on 404s, letting downstream tools process garbage
  (e.g., hashing an HTML error page).

## Checklist

### Workflow Structure

- [ ] CI workflow cross-checked against `brew tap-new` output
- [ ] `Homebrew/actions/setup-homebrew@main` used (NOT `actions/checkout`)
- [ ] `setup-homebrew` runs immediately after `actions/checkout` -- no file edits between them
- [ ] `git remote set-url origin` called with PAT before any `git push`
- [ ] `git push` specifies explicit remote and branch (`git push origin main`)
- [ ] `git config user.name` and `user.email` set after `setup-homebrew`, not before
- [ ] Runner matrix includes all target platforms
- [ ] `--only-formulae` gated to PR events only
- [ ] `--only-tap-syntax` runs on both push-to-main and PR

### Formula Files

- [ ] `sha256` line present in every formula (pre-seeded with `v0.0.0` URL + zeroed hash)
- [ ] No explicit `version` field when URL encodes the version
- [ ] `brew audit <formula-name>` passes locally (by name, never by path)

### Security

- [ ] External data assigned via job-level `env:`, never in `run:` with `${{ }}`
- [ ] `actions/checkout` pinned to full commit SHA
- [ ] `permissions` block set to least privilege
- [ ] Input validation: formula exists, version matches semver, repo matches org
- [ ] `curl --fail-with-body` used for HTTP downloads
- [ ] `workflow_dispatch` added alongside `repository_dispatch` for manual testing

### Dispatch Integration

- [ ] `gh api` used (not raw `curl`) for repository dispatch
- [ ] Token is fine-grained PAT scoped to tap repo with `contents: write`
- [ ] Dispatch fires after release creation (tarball must exist)

## Key Rules

1. **Never interpolate untrusted data in `run:` blocks.** Use job-level `env:` for
   `client_payload` and `inputs`. Reference as `$VAR`, never as `${{ }}` in shell.

2. **Never audit Homebrew formulas by file path.** Use `brew audit foo` (by name) or
   `brew test-bot --only-tap-syntax`. Always use `Homebrew/actions/setup-homebrew`.

3. **Pre-seed every mutable field with `v0.0.0`.** If a workflow will `sed`-update a value, ensure
   the field exists from day one with a placeholder. Use `v0.0.0` as the version -- never the real
   first release version, or `brew test-bot` rejects the sha256-only update.

4. **Use `--fail-with-body`, not `--fail`.** Plain `--fail` discards the error body. Without either
   flag, curl silently succeeds on 404s.

5. **Derive CI workflows from `brew tap-new`, not from scratch.** Homebrew's tooling has non-obvious
   constraints. The template encodes them correctly.

6. **`setup-homebrew` destroys three things: file edits, git credentials, and tracking branches.**
   Run it immediately after checkout. Re-authenticate git afterward. Use explicit
   `git push origin <branch>`. Every post-checkout operation must account for all three.

## Related Documentation

- [Automated formula updates plan](../../plans/2026-03-16-automated-formula-updates-plan.md) --
  the plan that drove this implementation
- [xurl-rs release plan][xurl-release] -- first consumer of this dispatch system
- [bird distribution plan][bird-release] -- second consumer

[xurl-release]: https://github.com/brettdavies/xurl-rs/blob/main/docs/plans/2026-03-16-001-feat-v1.0.3-initial-release-plan.md
[bird-release]: https://github.com/brettdavies/bird/blob/main/docs/plans/2026-03-16-003-feat-distribution-homebrew-crates-plan.md

- PR [#7](https://github.com/brettdavies/homebrew-tap/pull/7) /
  [#8](https://github.com/brettdavies/homebrew-tap/pull/8) -- move setup-homebrew before
  formula edits
- PR [#9](https://github.com/brettdavies/homebrew-tap/pull/9) /
  [#10](https://github.com/brettdavies/homebrew-tap/pull/10) -- use explicit remote and branch
  in git push
- PR [#11](https://github.com/brettdavies/homebrew-tap/pull/11) -- re-configure git auth after
  setup-homebrew symlink
- [Bottle publishing pipeline](./homebrew-bottle-publishing-pipeline-20260317.md) -- builds on this
  dispatch system to add pre-compiled bottles
