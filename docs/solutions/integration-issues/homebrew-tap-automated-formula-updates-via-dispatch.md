---
title: "Automated Homebrew formula updates via repository_dispatch with brew test-bot CI"
category: integration-issues
date: 2026-03-16
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
---

## Problem

Manual Homebrew formula updates after each release of xurl-rs or bird are error-prone, easy to forget, and don't scale. Each release requires downloading the tarball, computing the sha256, editing the formula, and pushing -- a process ripe for human error. The initial automation attempt also contained several security and correctness issues that had to be discovered and fixed.

## Root Cause

There is no built-in mechanism for Homebrew taps to receive updates when an upstream tool publishes a new release. The solution requires cross-repo CI/CD automation (repository_dispatch), but GitHub Actions has non-obvious security pitfalls (expression injection), Homebrew has underdocumented CI constraints (disabled path-based audit, required setup-homebrew action), and curl's default error handling silently masks download failures.

## Solution

### 1. Pre-seed sha256 in formulas

Ensure every formula has a `sha256` line from creation so the update workflow uses unconditional `sed` replacement instead of conditional insert-or-update logic.

```ruby
url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.0.3.tar.gz"
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

## What Didn't Work

- **Inline `${{ github.event.client_payload.* }}` in `run:` blocks** -- expression injection vulnerability. Attacker-controlled payloads can break out of string context and execute arbitrary commands. Fixed by moving to job-level `env:`.

- **`brew audit Formula/xurl-rs.rb` (path-based)** -- silently disabled by Homebrew. Exits 0, masking real errors. Must use `brew test-bot --only-tap-syntax` or audit by formula name.

- **`actions/checkout` for Homebrew CI** -- doesn't register the repo as a tap. `brew` commands operate against the published default branch, not the PR/push code. Must use `Homebrew/actions/setup-homebrew@main`.

- **`curl --fail`** -- discards the HTTP error body. A 404 gives only a generic error message with no context. `--fail-with-body` (curl 7.76+) preserves the response for diagnostics.

- **Conditional sha256 insert-or-update logic** -- fragile and doubles the test surface. Pre-seeding a placeholder makes updates a single unconditional `sed` substitution.

- **Raw `curl` for repository_dispatch** -- requires manual token header management. `gh api` handles auth automatically and gives better error output.

## Prevention Strategies

### Expression Injection

- **Always assign untrusted data to `env:` at job or step level.** Never interpolate `${{ github.event.client_payload.* }}`, `${{ inputs.* }}`, or `${{ github.event.issue.title }}` inside `run:` blocks.
- **Validate format before use.** Even after safe `env:` assignment, reject unexpected content with regex guards.
- **Detect existing violations:**

  ```bash
  rg '\$\{\{.*github\.event\.(client_payload|inputs|issue|pull_request)\.' --glob '*.yml' .github/workflows/
  ```

### Homebrew CI

- **Always use `Homebrew/actions/setup-homebrew@main`** as the first step in any workflow that runs `brew` commands.
- **Never call `brew audit` by file path.** Use formula name or `brew test-bot --only-tap-syntax`.
- **Gate `--only-formulae` to PRs only** (`if: github.event_name == 'pull_request'`).
- **Derive CI workflows from `brew tap-new` output**, not from scratch.

### curl Error Handling

- **Always use `--fail-with-body`** instead of `--fail` for HTTP downloads.
- Without either flag, curl silently succeeds on 404s, letting downstream tools process garbage (e.g., hashing an HTML error page).

## Checklist

### Workflow Structure

- [ ] CI workflow cross-checked against `brew tap-new` output
- [ ] `Homebrew/actions/setup-homebrew@main` used (NOT `actions/checkout`)
- [ ] Runner matrix includes all target platforms
- [ ] `--only-formulae` gated to PR events only
- [ ] `--only-tap-syntax` runs on both push-to-main and PR

### Formula Files

- [ ] `sha256` line present in every formula (pre-seeded if hash unknown)
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

1. **Never interpolate untrusted data in `run:` blocks.** Use job-level `env:` for `client_payload` and `inputs`. Reference as `$VAR`, never as `${{ }}` in shell.

2. **Never audit Homebrew formulas by file path.** Use `brew audit foo` (by name) or `brew test-bot --only-tap-syntax`. Always use `Homebrew/actions/setup-homebrew`.

3. **Pre-seed every mutable field.** If a workflow will `sed`-update a value, ensure the field exists from day one with a placeholder.

4. **Use `--fail-with-body`, not `--fail`.** Plain `--fail` discards the error body. Without either flag, curl silently succeeds on 404s.

5. **Derive CI workflows from `brew tap-new`, not from scratch.** Homebrew's tooling has non-obvious constraints. The template encodes them correctly.

## Related Documentation

- [Automated formula updates plan](../../plans/2026-03-16-automated-formula-updates-plan.md) -- the plan that drove this implementation
- [xurl-rs release plan](https://github.com/brettdavies/xurl-rs/blob/main/docs/plans/2026-03-16-001-feat-v1.0.3-initial-release-plan.md) -- first consumer of this dispatch system
- [bird distribution plan](https://github.com/brettdavies/bird/blob/main/docs/plans/2026-03-16-003-feat-distribution-homebrew-crates-plan.md) -- second consumer
