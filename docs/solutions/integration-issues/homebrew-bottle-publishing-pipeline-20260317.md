---
module: System
date: 2026-03-17
problem_type: integration_issue
component: development_workflow
symptoms:
  - "brew install brettdavies/tap/xurl-rs downloads 472MB of build dependencies (llvm, rust) for a 4.5MB binary"
  - "sed pattern s|sha256 \".*\"| matches ALL sha256 lines including bottle block, corrupting bottle hashes on 2nd+ release"
  - "No pre-compiled bottles available — every install compiles from source"
resolution_type: workflow_improvement
severity: high
tags: [homebrew, bottles, brew-pr-pull, workflow-run, ci-cd, github-actions, sed, bottle-safe]
---

# Automated Homebrew Bottle Publishing Pipeline

## Problem

Installing xurl-rs via `brew install` downloads 472MB of dependencies (llvm 368MB, rust 102MB) and installs
2GB of files to produce a 4.5MB binary. The Rust toolchain and LLVM are build-only dependencies users don't
need. The tap had no bottle publishing infrastructure, and the existing `update-formula.yml` pushed directly
to main, so `tests.yml` never built bottles (bottles are only built on PRs via `--only-formulae`).

## Environment

- Module: System-wide (CI/CD pipeline)
- Affected Component: `.github/workflows/update-formula.yml`, `.github/workflows/publish.yml`, `.github/workflows/guard-main-docs.yml`
- Date: 2026-03-17

## Symptoms

- `brew install brettdavies/tap/xurl-rs` downloads 472MB of build dependencies for a 4.5MB binary
- The `sed` pattern `s|sha256 ".*"|sha256 "${SHA256}"|` matches ALL sha256 lines in the formula,
  including those inside the `bottle do` block that `brew pr-pull` adds — on the 2nd+ release, every
  bottle SHA256 hash would be corrupted
- No pre-compiled bottles available; every install compiles from source

## What Didn't Work

**Direct push to main (original design):** The existing `update-formula.yml` pushed formula changes
directly to main. This meant `tests.yml` never ran with `--only-formulae` (which is gated to
`pull_request` events), so bottles were never built and never uploaded as artifacts.

**Standard `pr-pull` label pattern:** The canonical `brew tap-new` scaffold uses a `pr-pull` label to
trigger publishing. Most taps apply this label manually or add a separate auto-label workflow. This
requires either human intervention or a second workflow file, neither of which is fully automated.

**Unanchored sed for sha256:** The original `sed -i "s|sha256 \".*\"|sha256 \"${SHA256}\"|"` replaces
every sha256 line in the formula. After `brew pr-pull` adds a `bottle do` block with per-platform sha256
hashes, this sed would overwrite them all with the source tarball hash on the next release.

## Solution

Three workflow changes, zero formula changes:

### 1. Anchor sed to source sha256 only (bottle-safe)

```yaml
# Before (corrupts bottle hashes on 2nd+ release):
sed -i "s|sha256 \".*\"|sha256 \"${SHA256}\"|" "$F"

# After (only targets sha256 immediately following the url line):
sed -i '/^  url /{ n; s|sha256 ".*"|sha256 "'"${SHA256}"'"| }' "$F"
```

The `sed` address+next pattern finds the line starting with ` url `, advances to the next line, then
substitutes. Bottle sha256 lines don't follow a `url` line, so they're untouched.

### 2. Create PR instead of direct push

```yaml
- name: Create PR with formula update
  env:
    HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
    GH_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git remote set-url origin "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${{ github.repository }}.git"
    git add "Formula/${FORMULA}.rb"
    git diff --cached --quiet && echo "No changes" && exit 0
    BRANCH="update/${FORMULA}/v${VERSION}"
    git checkout -b "$BRANCH"
    git commit -m "chore(${FORMULA}): bump to v${VERSION}"
    git push --force origin "$BRANCH"
    gh pr create \
      --title "chore(${FORMULA}): bump to v${VERSION}" \
      --body "Automated formula update for ${FORMULA} v${VERSION}." \
      --base main \
      --head "$BRANCH"
```

Creating a PR to main triggers `tests.yml` with `--only-formulae`, which builds bottles and uploads them as artifacts.

### 3. Add publish.yml with workflow_run trigger

```yaml
on:
  workflow_run:
    workflows: ["brew test-bot"]
    types: [completed]
  workflow_dispatch:
    inputs:
      pull_request:
        description: "PR number to publish bottles for"
        required: true
      branch:
        description: "Branch name (e.g., update/xurl-rs/v1.0.5)"
        required: true
```

Key steps:

- **PR author verification:** `--author "app/github-actions"` in `gh pr list` ensures only bot-created PRs are processed
- **PR number integer validation:** Regex `^[0-9]+$` prevents injection
- **`brew pr-pull`:** Downloads bottle artifacts, uploads to GitHub Release, adds `bottle do` block to formula, commits
- **`git-try-push`:** Pushes bottle commit directly to main (uses PAT with admin bypass)
- **Branch deletion:** Cleans up the `update/*` branch after publish

### 4. Fix guard-main-docs for release branches

```javascript
// Before (blocks all docs files, even deletions):
const forbidden = files
  .map(f => f.filename)
  .filter(f => f.startsWith('docs/plans/') || ...);

// After (only blocks added/modified docs):
const forbidden = files
  .filter(f => f.status === 'added' || f.status === 'modified')
  .map(f => f.filename)
  .filter(f => f.startsWith('docs/plans/') || ...);
```

## Why This Works

The root cause was that the tap had no mechanism to build and publish pre-compiled bottles. The existing
pipeline pushed directly to main, bypassing the PR-based bottle build process entirely.

The solution creates a PR-based pipeline where:

1. `update-formula.yml` creates a PR (not a direct push) — this triggers `tests.yml`
2. `tests.yml` builds bottles on 3 platforms and uploads artifacts (already existed, just never
   triggered)
3. `publish.yml` fires via `workflow_run` when tests complete, runs `brew pr-pull` to download
   artifacts, upload bottles to GitHub Release, and add the `bottle do` block

The `workflow_run` trigger replaces the standard `pr-pull` label pattern, eliminating all manual steps.
The anchored `sed` ensures the bottle block survives subsequent formula updates.

## Prevention

1. **Always anchor sed patterns in Homebrew formulas.** When a formula may contain multiple sha256 lines
   (source + bottles), use address patterns (`/^  url /{ n; ... }`) to target only the intended line.

2. **Formula updates must go through PRs.** Direct pushes to main bypass `--only-formulae` and bottle
   building. Any workflow that updates formulas should create a PR, not push directly.

3. **`workflow_run` must exist on the default branch.** Like `pull_request_target`, `workflow_run` reads
   the workflow definition from the default branch. The workflow file must be merged to main before it
   can fire.

4. **Verify PR author in publish workflows.** Use `--author "app/github-actions"` to prevent fork
   contributors from triggering bottle publishing by naming their branch `update/*`.

5. **Test with `actionlint`.** Run `actionlint` on all workflow files before committing to catch YAML
   and GitHub Actions expression errors.

6. **Pre-seed new formulas with `v0.0.0`, not the real first version.** If the pre-seeded URL matches
   the first release version, the dispatch updates only the sha256. `brew test-bot` rejects this:
   "stable sha256 changed without the url/version also changing." Using `v0.0.0` ensures the first
   dispatch changes both URL and sha256.

## Related Issues

- See also:
  [homebrew-tap-automated-formula-updates-via-dispatch.md](./homebrew-tap-automated-formula-updates-via-dispatch.md)
  — the dispatch automation this builds on (setup-homebrew symlink, git credential, sed pattern
  pitfalls)
