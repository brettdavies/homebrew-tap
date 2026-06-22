# Plan: Automated Formula Updates via Repository Dispatch

**Date:** 2026-03-16
**Status:** completed
**Brainstorm:** `~/dev/xurl-rs/docs/brainstorms/2026-03-16-initial-release-brainstorm.md`

## Enhancement Summary

**Deepened on:** 2026-03-16
**Sections enhanced:** 7
**Research agents used:** best-practices-researcher, framework-docs-researcher,
security-sentinel, architecture-strategist, pattern-recognition-specialist,
code-simplicity-reviewer, spec-flow-analyzer, repo-research-analyst

### Key Improvements

1. Critical security fix: payload injection vulnerability via `${{ }}` expression injection
2. Simplified workflow: job-level `env` eliminates extraction step; pre-seeded sha256 eliminates conditional logic
3. Added `permissions`, `curl --fail-with-body` on tarball download, and `actions/checkout` SHA pinning
4. Added `workflow_dispatch` trigger for manual testing via GitHub UI
5. Added official `tests.yml` CI workflow (`brew test-bot`) from `brew tap-new` template

### New Considerations Discovered

- GitHub archive hashes are stable for no less than one year per GitHub's commitment
  (Feb 2023), with six months' notice before any format changes -- low risk for personal tap
- `HOMEBREW_TAP_TOKEN` should use fine-grained PAT with `contents: write` permission on
  `brettdavies/homebrew-tap` only
- The `git config` email should use `41898282+github-actions[bot]@users.noreply.github.com`
  (the canonical bot email)
- Path-based `brew audit` (`brew audit Formula/foo.rb`) is disabled by Homebrew -- must audit
  by formula name or use `brew test-bot --only-tap-syntax`
- `brew test-bot --only-tap-syntax` runs `brew audit --except=installed --tap=<tap>`,
  `brew style <tap>`, and `brew readall --aliases --os=all --arch=all <tap>`
- `Homebrew/actions/setup-homebrew` is required for any brew commands in CI -- it symlinks the
  repo into the correct tap directory so brew operates on PR/push code, not the published
  default branch

---

## Solution Documentation

- [`docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md`][dispatch-solution]
  — compounded learnings: expression injection, brew CI pitfalls, curl error handling,
  pre-seeding simplification

[dispatch-solution]: ../solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md

---

## Problem

When xurl-rs (or bird) cuts a release, the Homebrew formula in this repo must
be updated with the new version and SHA256 hash. Currently this is a manual
step -- error-prone and easy to forget.

## Solution

A GitHub Actions workflow in this repo that:

1. Receives `repository_dispatch` events from tool repos (xurl-rs, bird)
2. Downloads the release source tarball
3. Computes the SHA256
4. Updates the formula file with the new version and hash
5. Commits and pushes

Plus the official `brew test-bot` CI workflow to validate all formula changes.

## Architecture

```text
xurl-rs release.yml                    homebrew-tap
========================                ========================
tag push v1.0.4
  -> build (5 targets)
  -> create GitHub Release
  -> publish to crates.io
  -> gh api dispatch ------------->  update-formula.yml
     event: update-formula                -> receive event payload
     payload:                             -> curl tarball | sha256sum
       formula: xurl-rs                   -> sed formula with version + sha
       version: 1.0.4                     -> git commit + push
       repo: brettdavies/xurl-rs               |
                                                v
                                          tests.yml (push to main)
                                                -> brew test-bot --only-tap-syntax
                                                -> brew audit + style + readall
```

### Research Insights

**Why `repository_dispatch` is the right pattern:**

- Push-based (tool repo triggers update) vs. pull-based (tap polls for changes) -- push is simpler and immediate
- Alternatives considered: `workflow_dispatch` (requires manual trigger), polling (wasteful,
  delayed), GitHub App (overkill for 2 repos)
- `repository_dispatch` is the canonical cross-repo automation pattern per GitHub docs

**Why `sed` is acceptable for formula updates:**

- The formula files are tiny (17-18 lines), well-structured, and follow a stable Homebrew convention
- The `url` and `sha256` lines have predictable, unique patterns
- Alternatives (Ruby script, `brew bump-formula-pr`) would add complexity without proportional benefit for a personal tap
- `brew bump-formula-pr` is designed for the homebrew-core contribution workflow, not for self-managed taps

## Implementation

### Task 0: Pre-seed sha256 in both formulas (prerequisite)

**Files:** `Formula/xurl-rs.rb`, `Formula/bird.rb`

Compute the real SHA256 hashes for the current versions and add `sha256` lines to both
formulas. This eliminates the conditional insert-or-update logic from the workflow (the
"insert" path would fire at most twice, then never again).

```bash
# Compute real hashes
curl -sL https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.0.3.tar.gz | sha256sum
curl -sL https://github.com/brettdavies/bird/archive/refs/tags/v0.1.0.tar.gz | sha256sum
```

Add the resulting hash after the `url` line in each formula:

```ruby
url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.0.3.tar.gz"
sha256 "<computed-hash>"
```

**Rationale:** Removes a code path and failure mode from the workflow. The workflow becomes two unconditional `sed` substitutions.

### Task 1: Create `update-formula.yml` in homebrew-tap

**File:** `.github/workflows/update-formula.yml`

```yaml
name: Update Formula

on:
  repository_dispatch:
    types: [update-formula]
  workflow_dispatch:
    inputs:
      formula:
        description: "Formula name (e.g., xurl-rs)"
        required: true
      version:
        description: "Version without v prefix (e.g., 1.0.4)"
        required: true
      repo:
        description: "GitHub repo (e.g., brettdavies/xurl-rs)"
        required: true

permissions:
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    env:
      FORMULA: ${{ github.event.client_payload.formula || inputs.formula }}
      VERSION: ${{ github.event.client_payload.version || inputs.version }}
      REPO: ${{ github.event.client_payload.repo || inputs.repo }}
    steps:
      - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

      - name: Validate inputs
        run: |
          if [[ -z "$FORMULA" || -z "$VERSION" || -z "$REPO" ]]; then
            echo "::error::Missing required fields: formula, version, or repo"
            exit 1
          fi
          if [[ ! -f "Formula/${FORMULA}.rb" ]]; then
            echo "::error::Formula file not found: Formula/${FORMULA}.rb"
            exit 1
          fi
          if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "::error::Invalid version format: ${VERSION} (expected X.Y.Z)"
            exit 1
          fi
          if [[ ! "$REPO" =~ ^brettdavies/ ]]; then
            echo "::error::Repo must be under brettdavies/ org: ${REPO}"
            exit 1
          fi

      - name: Download tarball and compute SHA256
        run: |
          TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"
          SHA=$(curl --fail-with-body -sL "$TARBALL_URL" | sha256sum | awk '{print $1}')
          echo "SHA256=$SHA" >> "$GITHUB_ENV"

      - name: Update formula
        run: |
          F="Formula/${FORMULA}.rb"
          sed -i "s|url \"https://github.com/${REPO}/archive/refs/tags/v.*\.tar\.gz\"|url \"https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz\"|" "$F"
          sed -i "s|sha256 \".*\"|sha256 \"${SHA256}\"|" "$F"

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add "Formula/${FORMULA}.rb"
          git diff --cached --quiet && echo "No changes" && exit 0
          git commit -m "chore(${FORMULA}): bump to v${VERSION}"
          git push
```

**Key design decisions:**

- Generic -- works for any formula, not hardcoded to xurl-rs or bird
- Payload-driven -- the calling repo specifies formula name, version, and repo
- Idempotent -- `git diff --cached --quiet` exits cleanly if no changes
- Job-level `env` -- eliminates the separate "Extract event payload" step
- Two unconditional `sed` commands -- no conditional logic (sha256 pre-seeded in Task 0)
- `curl --fail-with-body` -- returns non-zero on HTTP errors AND preserves the error response
  body for diagnostics (unlike `--fail` which discards it). Available since curl 7.76.0
  (2021), pre-installed on all current GitHub-hosted runners.

### Research Insights: Security

**Expression injection (CRITICAL FIX applied above):**
The original plan used `${{ github.event.client_payload.formula }}` directly in
`echo ... >> "$GITHUB_ENV"`. This is vulnerable to expression injection -- if a
payload value contains shell metacharacters or newlines, it can inject arbitrary
environment variables or execute code. The fix: use job-level `env:` blocks
which are handled by the Actions runtime (not shell-interpolated), and validate
inputs before using them in shell commands.

**Additional security hardening applied:**

- `permissions: contents: write` -- explicit least-privilege (only needs to push)
- `actions/checkout` pinned to full SHA (not mutable tag)
- `curl --fail-with-body` -- returns non-zero on HTTP errors (404, 500) instead of silently
  hashing an error page, and preserves the error body for diagnostics
- Input validation -- checks formula file exists, version matches semver, repo is under `brettdavies/`
- `workflow_dispatch` -- allows manual testing from GitHub UI without needing API access

### Task 2: Create `tests.yml` in homebrew-tap (official brew test-bot CI)

**File:** `.github/workflows/tests.yml`

This is the official CI workflow generated by `brew tap-new`. It validates all
formulas on every push to main and on every PR. The push-to-main trigger is
critical: when `update-formula.yml` pushes a formula change, this workflow
automatically validates it via `brew test-bot --only-tap-syntax` (which runs
`brew audit`, `brew style`, and `brew readall` against the entire tap).

```yaml
name: brew test-bot

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  test-bot:
    strategy:
      matrix:
        os: [ubuntu-24.04, macos-14, macos-15]
    runs-on: ${{ matrix.os }}
    permissions:
      actions: read
      checks: read
      contents: read
      pull-requests: read
    steps:
      - name: Set up Homebrew
        id: set-up-homebrew
        uses: Homebrew/actions/setup-homebrew@main
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Cache Homebrew Bundler RubyGems
        uses: actions/cache@v4
        with:
          path: ${{ steps.set-up-homebrew.outputs.gems-path }}
          key: ${{ matrix.os }}-rubygems-${{ steps.set-up-homebrew.outputs.gems-hash }}
          restore-keys: ${{ matrix.os }}-rubygems-

      - run: brew test-bot --only-cleanup-before

      - run: brew test-bot --only-setup

      - run: brew test-bot --only-tap-syntax

      - run: brew test-bot --only-formulae
        if: github.event_name == 'pull_request'

      - name: Upload bottles as artifact
        if: always() && github.event_name == 'pull_request'
        uses: actions/upload-artifact@v4
        with:
          name: bottles_${{ matrix.os }}
          path: '*.bottle.*'
```

**What each phase does:**

| Phase | What it validates |
| ----- | ----------------- |
| `--only-cleanup-before` | Resets stale state, deletes leftover bottle files |
| `--only-setup` | Installs Ruby gems for auditing/bottling, runs `brew config` and `brew doctor` |
| `--only-tap-syntax` | Runs `brew audit --except=installed --tap=<tap>`, `brew style <tap>`, `brew readall --aliases --os=all --arch=all <tap>` |
| `--only-formulae` | PR-only: installs formula from source, runs `brew test`, runs `brew audit --new` (for new formulas) or `brew audit --git --skip-style` (for existing), creates bottles |

**Why `Homebrew/actions/setup-homebrew` instead of `actions/checkout`:**

`brew tap` clones the **published** default branch, not the PR branch. `setup-homebrew`
symlinks `GITHUB_WORKSPACE` into the Homebrew tap directory so all `brew` commands
operate on the PR code. This is the only officially supported way to run brew CI
on a tap.

**Why `--only-formulae` is gated to PRs:**

It needs a git diff to detect which formulas changed. On pushes to main, the
`--only-tap-syntax` phase is sufficient -- it validates all formulas in the tap
via `brew audit`, `brew style`, and `brew readall`.

### Research Insights: Homebrew Conventions

**Homebrew version detection:**
Homebrew auto-detects version from the tarball URL pattern
(`/tags/v1.0.3.tar.gz` -> version `1.0.3`). No explicit `version` field is
needed in the formula. The sed update to the URL is sufficient. `brew audit`
will actually warn if you add a redundant explicit `version` that matches what
would be auto-detected from the URL.

**Post-update validation strategy:**
The `update-formula.yml` workflow pushes directly to main. This triggers
`tests.yml`, which runs `brew test-bot --only-tap-syntax` -- validating
syntax, audit, and style on all three platforms (ubuntu, macOS Intel, macOS ARM).
This catches formula errors automatically without needing inline `brew audit`
in the update workflow itself.

**Bottles (future enhancement):**
`brew tap-new` also generates a `publish.yml` workflow for bottle publishing via
PR labels. For Rust formulas that take significant time to compile, bottles
(pre-compiled packages) would improve install speed for users. This is not
required for initial launch but can be added later.

### Research Insights: Simplification

**What was removed from the original plan:**

- Separate "Extract event payload" step (7 lines) -- replaced with job-level `env:`
- Conditional sha256 insert-or-update logic (4 lines) -- eliminated by pre-seeding sha256 in Task 0
- `cat "$FORMULA_FILE"` debug output -- removed (git diff shows changes)
- Incorrect inline `brew audit` step (path-based audits are disabled) -- replaced with official `tests.yml` workflow

**What was added:**

- `workflow_dispatch` trigger for manual testing via GitHub UI
- Input validation step (formula exists, version format, repo ownership)
- `curl --fail-with-body` for error detection with diagnostics
- `permissions: contents: write` for least privilege
- SHA-pinned `actions/checkout`
- Official `tests.yml` CI workflow (`brew test-bot`) for automated formula validation
- `Homebrew/actions/setup-homebrew` for correct tap setup in CI

## Acceptance Criteria

- [x] sha256 lines present in both `Formula/xurl-rs.rb` and `Formula/bird.rb` (Task 0)
- [x] `update-formula.yml` exists in `homebrew-tap/.github/workflows/`
- [x] `tests.yml` exists in `homebrew-tap/.github/workflows/` (official `brew test-bot` CI)
- [x] `tests.yml` uses `Homebrew/actions/setup-homebrew` (not `actions/checkout` + `brew tap`)
- [x] `tests.yml` matrix includes `ubuntu-24.04`, `macos-14`, `macos-15`
- [x] `update-formula.yml` accepts both `repository_dispatch` and `workflow_dispatch` triggers
- [x] `update-formula.yml` validates inputs before acting on them
- [x] `update-formula.yml` is generic -- driven by event payload, not hardcoded to one formula
- [x] `actions/checkout` pinned to full SHA in `update-formula.yml`, not mutable tag
- [x] `permissions` block limits token to `contents: write` in `update-formula.yml`
- [x] Formula file is valid Ruby after automated update (validated by `tests.yml` push trigger)
- [x] `curl --fail-with-body` used in tarball download step

## Testing Strategy

1. **Local validation:** Run the sha256 computation locally and verify the
   formula is valid Ruby after manual sed update
2. **`workflow_dispatch` test:** Trigger the `update-formula.yml` workflow from
   the GitHub Actions UI with known-good inputs (current version) to verify
   idempotent behavior
3. **`tests.yml` validation:** After the push from step 2, verify `tests.yml`
   triggers and `brew test-bot --only-tap-syntax` passes on all three platforms
4. **Manual dispatch test:** Trigger via `gh` CLI to simulate the repository_dispatch path

```bash
# Manual dispatch test (from any machine with gh CLI)
gh api repos/brettdavies/homebrew-tap/dispatches \
  --method POST \
  -f event_type=update-formula \
  -f 'client_payload[formula]=xurl-rs' \
  -f 'client_payload[version]=1.0.3' \
  -f 'client_payload[repo]=brettdavies/xurl-rs'
```

### Research Insights: Edge Cases to Test

- **Tarball 404:** Test with a non-existent version to verify `curl --fail-with-body` exits
  non-zero and shows the error response
- **Invalid formula name:** Dispatch with `formula=nonexistent` to verify the validation step catches it
- **Idempotent re-run:** Dispatch with the current version to verify "No changes" exit
- **Version format:** Dispatch with `version=v1.0.3` (with v prefix) to verify validation rejects it
- **`tests.yml` failure:** Manually break a formula (invalid Ruby syntax) on a branch and
  open a PR to verify `brew test-bot` catches it

## Dependencies

| Dependency | Status |
| ---------- | ------ |
| `Formula/xurl-rs.rb` exists | Done |
| `Formula/bird.rb` exists | Done |
| sha256 lines in both formulas | Done (Task 0) |
| `tests.yml` in homebrew-tap | Done (Task 2) |
| Tool repos must be public | External (required for tarball download) |
| Tool repos dispatch via `repository_dispatch` | External (see xurl-rs and bird plans) |
| `HOMEBREW_TAP_TOKEN` set on tool repos | External (see xurl-rs and bird plans) |

## Risks

- **Tarball not available yet:** The dispatch fires after `release` job, but the
  source tarball is created by GitHub when the tag is pushed -- it should be
  available before the release job even starts. Low risk. **Mitigated by
  `curl --fail-with-body` which will fail the workflow with diagnostics instead
  of silently hashing an error page.**
- **Formula syntax breakage:** The sed commands could produce invalid Ruby if the
  formula format changes. Low risk -- the formula structure is stable and minimal.
  **Mitigated by `tests.yml` which runs `brew test-bot --only-tap-syntax`
  (including `brew audit` and `brew readall`) on every push to main.**
- **Race condition:** If two releases fire simultaneously, commits could conflict.
  Extremely unlikely for a single-maintainer project. Accept the risk.
- **GitHub archive hash instability:** GitHub commits to archive hash stability
  for no less than one year with six months' notice before changes (Feb 2023
  commitment). Low risk for a personal tap where hashes are recomputed on every
  update anyway.
- **Token compromise:** If `HOMEBREW_TAP_TOKEN` is leaked, an attacker could push
  arbitrary changes to the tap. **Mitigated by: (1) input validation restricts
  repo to `brettdavies/` org, (2) using fine-grained PAT with minimal scope,
  (3) the workflow only modifies formula files, not arbitrary paths, (4)
  `tests.yml` validates all formula changes via `brew audit` on push.**
