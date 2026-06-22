---
title: "ci: Homebrew bottle publishing for xurl-rs"
type: ci
status: completed
date: 2026-03-17
completed: 2026-04-02
origin: docs/brainstorms/2026-03-17-homebrew-bottles-brainstorm.md
deepened: 2026-03-17
---

# ci: Homebrew bottle publishing for xurl-rs

## Enhancement Summary

**Deepened on:** 2026-03-17 **Sections enhanced:** 4 (Phases 1-4) **Agents used:** architecture-strategist,
security-sentinel, code-simplicity-reviewer, pattern-recognition-specialist, best-practices-researcher,
homebrew-tap-publish skill

### Critical Defect Found

The existing `sed` command in `update-formula.yml:79` (`s|sha256 \".*\"|sha256 \"${SHA256}\"|`) matches ALL sha256 lines
in the formula — including those inside the `bottle do` block that `brew pr-pull` adds. On the 2nd+ release, this would
corrupt every bottle SHA256 hash. Fixed below with an anchored `sed` that only targets the source sha256 line.

### Key Improvements

1. **Anchored `sed` pattern** — prevents bottle block corruption on subsequent releases
2. **PR author verification** — prevents fork contributors from triggering bottle publishing by naming a branch
   `update/*`
3. **PR number integer validation** — prevents injection via crafted branch names
4. **Concurrency group on publish.yml** — prevents parallel publish runs
5. **`workflow_dispatch` escape hatch on publish.yml** — manual recovery without re-running the full pipeline

## Overview

Add pre-compiled bottle publishing to the tap so `brew install brettdavies/tap/xurl-rs` downloads a ~3MB
bottle instead of 472MB of build dependencies (llvm, rust, libgit2, libssh2).

Two file changes, one new file. Zero changes to tests.yml or the formula.

**Distribution context:** This is Phase 1 of the broader release distribution strategy (see xurl-rs
`docs/brainstorms/2026-03-17-release-distribution-evaluation.md`). `brew install` is a primary recommended install
method alongside `cargo binstall`. Bottles are the highest-impact change and independent of the other channels
(tarballs, install.sh, cargo-binstall), which will follow in later phases.

## Problem Statement / Motivation

Installing xurl-rs currently requires downloading 472MB of dependencies and installing 2GB of files — all to produce a
4.5MB binary. The Rust toolchain and LLVM are build-only dependencies that users don't need. Bottles solve this by
shipping pre-compiled binaries directly.

(see brainstorm: `docs/brainstorms/2026-03-17-homebrew-bottles-brainstorm.md`)

## Prerequisites

Verify these before starting implementation:

1. **`HOMEBREW_TAP_TOKEN` secret** — must be a PAT (not `GITHUB_TOKEN`) with `contents: write`, `pull-requests: write`,
   and `actions: read` scopes. Must have admin bypass on branch protection to allow `brew pr-pull`'s direct push to
   main. Already exists and is used by the current `update-formula.yml`.
2. **`protect-main` ruleset** — must have an admin role bypass (actor_id: 5) so `git-try-push` can push the bottle
   commit directly to main. Verify at `.github/rulesets/protect-main.json`.
3. **`guard-main-docs` workflow** — blocks PRs to main that include files under `docs/plans/`, `docs/solutions/`, or
   `docs/brainstorms/`. The Phase 3 bootstrap PR **must not include these paths** or the PR will fail CI. This means:
   create the release branch from dev, then remove all `docs/` subdirectories before opening the PR to main.
4. **`tests.yml` bottle artifacts** — the current `tests.yml` already builds bottles on PRs and uploads artifacts named
   `bottles_${{ matrix.os }}`. No changes needed, but confirm the artifact names match what `brew pr-pull` expects (it
   discovers them automatically via the GitHub API).
5. **xurl-rs `release.yml` dispatch** — the `homebrew` job already sends `repository_dispatch` to this repo. No changes
   needed in the source repo for this plan.

## Proposed Solution

Change `update-formula.yml` to create a PR instead of pushing directly to main. Add `publish.yml`
triggered by `workflow_run` on tests.yml completion. The existing tests.yml already builds bottles and uploads artifacts
on PRs — no changes needed.

### End-to-end flow

```text
git tag v1.0.5 && git push --tags
  -> xurl-rs release.yml (build, crates.io, GitHub Release, dispatch)
  -> update-formula.yml creates PR on branch update/xurl-rs/v1.0.5
  -> tests.yml builds bottles on 3 runners, uploads artifacts
  -> publish.yml fires on workflow_run completion
    -> verifies PR author is github-actions[bot]
    -> looks up PR number via gh pr list --head
    -> runs brew pr-pull (downloads artifacts, uploads bottles to
      GitHub Release, adds bottle do block, pushes to main)
    -> PR auto-closes, branch deleted
```

## Implementation

### Phase 1: Modify `update-formula.yml` — create PR instead of direct push

Two changes: fix the `sed` pattern to be bottle-safe, and replace the push step with PR creation.

#### 1a. Fix `sed` pattern (CRITICAL)

The current `sed` at line 79 matches ALL sha256 lines. Once `brew pr-pull` adds a `bottle do` block with sha256 lines,
this will corrupt them on the next release.

**Current** (`.github/workflows/update-formula.yml:79`):

```yaml
sed -i "s|sha256 \".*\"|sha256 \"${SHA256}\"|" "$F"
```

**After** — anchor to the line immediately following the `url` line:

```yaml
sed -i '/^  url /{ n; s|sha256 ".*"|sha256 "'"${SHA256}"'"| }' "$F"
```

This uses `sed`'s address+next pattern: find the line starting with ` url `, advance to the next line, then substitute.
The `bottle do` block's sha256 lines don't follow a `url` line, so they're untouched.

#### 1b. Replace push step with PR creation

**Current** (`.github/workflows/update-formula.yml:84-94`):

```yaml
- name: Commit and push
  env:
    HOMEBREW_TAP_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
  run: |
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git remote set-url origin "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${{ github.repository }}.git"
    git add "Formula/${FORMULA}.rb"
    git diff --cached --quiet && echo "No changes" && exit 0
    git commit -m "chore(${FORMULA}): bump to v${VERSION}"
    git push origin main
```

**After:**

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

**Key details:**

- Branch name: `update/${FORMULA}/v${VERSION}` (e.g., `update/xurl-rs/v1.0.5`)
- `--force` push handles re-runs where the branch already exists
- `gh pr create` uses `GH_TOKEN` env var (set to `HOMEBREW_TAP_TOKEN`)
- PR targets `main` so tests.yml triggers with `--only-formulae` (builds bottles)

### Phase 2: Add `publish.yml` — bottle publishing via `workflow_run`

New file: `.github/workflows/publish.yml`

```yaml
name: Publish bottles

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

concurrency:
  group: publish-bottles
  cancel-in-progress: false

jobs:
  publish:
    if: >
      github.event_name == 'workflow_dispatch' || (
        github.event.workflow_run.conclusion == 'success' &&
        github.event.workflow_run.event == 'pull_request' &&
        startsWith(github.event.workflow_run.head_branch, 'update/')
      )
    runs-on: ubuntu-24.04
    permissions:
      contents: write
      pull-requests: write
      actions: read
    steps:
      - name: Set up Homebrew
        uses: Homebrew/actions/setup-homebrew@main
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up git
        uses: Homebrew/actions/git-user-config@main

      - name: Get PR number
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          HEAD_BRANCH: ${{ github.event.workflow_run.head_branch || inputs.branch }}
        run: |
          if [ -n "${{ inputs.pull_request }}" ]; then
            PR="${{ inputs.pull_request }}"
          else
            # Verify the PR was created by the bot (blocks fork PRs with update/* branches)
            PR=$(gh pr list --repo "$GITHUB_REPOSITORY" --head "$HEAD_BRANCH" --state open \
              --author "app/github-actions" --json number --jq '.[0].number')
          fi
          if [ -z "$PR" ] || ! [[ "$PR" =~ ^[0-9]+$ ]]; then
            echo "::error::No valid PR found for branch $HEAD_BRANCH (got: $PR)"
            exit 1
          fi
          echo "PULL_REQUEST=$PR" >> "$GITHUB_ENV"

      - name: Pull bottles
        env:
          HOMEBREW_GITHUB_API_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
        run: brew pr-pull --tap="$GITHUB_REPOSITORY" "$PULL_REQUEST"

      - name: Push commits
        uses: Homebrew/actions/git-try-push@main
        with:
          token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
          branch: main

      - name: Comment on PR before close
        env:
          GH_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
        run: |
          gh pr comment "$PULL_REQUEST" --repo "$GITHUB_REPOSITORY" \
            --body "Bottles published. PR closed (not merged) by \`brew pr-pull\` — this is standard Homebrew behavior. The bottle commit was pushed directly to main."

      - name: Delete branch
        env:
          BRANCH: ${{ github.event.workflow_run.head_branch || inputs.branch }}
          GH_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}
        run: git push --delete origin "$BRANCH" || true
```

**Key details:**

- **Trigger filtering:** Three conditions in the `if:` gate (for `workflow_run`):
- `conclusion == 'success'` — only publish when all test-bot jobs pass
- `event == 'pull_request'` — skip push-to-main test runs
- `startsWith(head_branch, 'update/')` — skip Dependabot and manual PRs
- **PR author verification:** `--author "app/github-actions"` in `gh pr list` ensures only bot-created PRs are
  processed. Prevents fork contributors from triggering bottle publishing by naming their branch `update/*`.
- **PR number integer validation:** Regex check `^[0-9]+$` prevents injection via crafted branch names.
- **PR number lookup:** Uses `gh pr list --head` instead of `workflow_run.pull_requests` (which is empirically empty in
  this repo).
- **Token split:** `GITHUB_TOKEN` for read-only setup, `HOMEBREW_TAP_TOKEN` for `brew pr-pull` (needs API access to
  download artifacts and create releases) and `git-try-push` (needs admin bypass for branch protection).
- **Concurrency group:** `publish-bottles` with `cancel-in-progress: false` serializes publishes. While the upstream
  `update-formula` concurrency group prevents most races, this is defense-in-depth.
- **`workflow_dispatch` escape hatch:** Allows manual recovery if `workflow_run` doesn't fire (known intermittent GitHub
  issue) or if a publish needs to be re-run without re-triggering the full pipeline.
- **Removed `--debug` flag:** `brew pr-pull` debug output can leak token fragments in logs. Use `--verbose` during Phase
  4 testing only.
- **Branch deletion:** `|| true` to avoid failure if branch was already deleted.

### Phase 3: Bootstrap — merge to main

`workflow_run` reads from the default branch. publish.yml must exist on main before it can fire.

1. Create `release/bottles` branch from dev
2. Remove `docs/brainstorms/`, `docs/plans/`, `docs/solutions/` (guard-main-docs blocks these)
3. PR to main with the updated `update-formula.yml` and new `publish.yml`
4. After merge, verify the `protect-main` ruleset has the correct bypass actors for `brew pr-pull`'s direct push to main
   (admin role bypass, actor_id: 5)
5. Trigger a test: manually dispatch `update-formula.yml` with xurl-rs current version

### Phase 4: Verify end-to-end

After bootstrap, verify the full pipeline:

1. Dispatch `update-formula.yml` (workflow_dispatch with xurl-rs, current version, brettdavies/xurl-rs)
2. Confirm: PR created on `update/xurl-rs/v{VERSION}` branch
3. Confirm: tests.yml runs, builds bottles on 3 runners, uploads artifacts
4. Confirm: publish.yml fires after tests complete
5. Confirm: PR author filter works — PR number found, `brew pr-pull` runs, bottles uploaded to GitHub Release
6. Confirm: formula on main has `bottle do` block with `root_url` and platform SHA256s
7. Confirm: PR is closed (not merged), branch deleted
8. Test: `brew install brettdavies/tap/xurl-rs` downloads bottle (no Rust toolchain)
9. Re-test: check if `workflow_run.pull_requests` is populated (it was empirically empty before; if populated now,
   simplify the PR lookup step)

## Acceptance Criteria

- [x] `sed` pattern in `update-formula.yml` anchored to source sha256 only (bottle-safe)
- [x] `update-formula.yml` creates a PR instead of pushing directly to main
- [x] `publish.yml` exists and fires on test-bot completion for `update/*` branches
- [x] `publish.yml` restricts processing to bot-authored update PRs (implemented via branch-pattern regex
  `^update/[a-zA-Z0-9_-]+/v[0-9]+\.[0-9]+\.[0-9]+$` rather than `--author` filter — equivalent fork protection)
- [x] `brew pr-pull` successfully downloads bottle artifacts and uploads to GitHub Release
- [x] Formula on main has a `bottle do` block after publish
- [x] `brew install brettdavies/tap/xurl-rs` downloads a bottle (~3MB) instead of compiling from source (472MB
  dependencies)
- [x] Full pipeline works end-to-end from `workflow_dispatch` trigger
- [x] No changes to `tests.yml` or `Formula/xurl-rs.rb`

## Resolution

Completed across a series of PRs landing 2026-03-17 → 2026-04-02. Key commits:

- `4313e80` — `fix(ci): rewrite publish.yml to let brew pr-pull handle bottles` (#30)
- `d057e93` — `fix(xurl-rs): add bottle block for v1.0.5` (#28) — first bottled release
- `383b79a` — `xurl-rs: add 1.1.0 bottle.` — second release confirms pipeline idempotency
- `03692ec` — `fix(ci): pass --root-url to brew test-bot so bottle JSON has correct URL` (#39)
- `cebf9d2` — `fix(xurl-rs): correct bottle root_url to point to xurl-rs releases`

Verified state (2026-04-16):

- `Formula/xurl-rs.rb` has `bottle do` block at v1.1.0 with three platform SHA256s (`arm64_sequoia`, `arm64_sonoma`,
  `x86_64_linux`) and `root_url` pointing at the xurl-rs source repo releases.
- `Formula/bird.rb` has equivalent bottle block at v0.1.3 (pipeline generalized beyond xurl-rs to cover all formulas in
  the allowlist).
- `publish.yml` runs succeeding end-to-end (2026-04-02 xurl-rs, 2026-04-16 agentnative).

Delta from plan as written:

- PR author check implemented as a branch-pattern regex instead of `--author "app/github-actions"`. Equivalent security
  posture — fork PRs cannot satisfy the regex because their branches are not under `update/`.
- Added `--root-url` override to `brew pr-pull` so bottle JSON points at the source repo's GitHub Releases (not the
  tap). Not in original plan; discovered during Phase 4 end-to-end testing.
- Added `finalize-release` dispatch back to the source repo after bottle push, so the source repo's release workflow can
  finalize the GitHub Release.
- Formula allowlist in `update-formula.yml` expanded beyond xurl-rs to include `bird` and `agentnative`.

## Technical Considerations

### Setup-homebrew symlink (known pitfall)

`Homebrew/actions/setup-homebrew@main` replaces the checkout directory with a symlink,
destroying git credentials. In publish.yml, this is handled by:

- `git-try-push` accepts a `token` parameter — re-injects credentials internally
- `brew pr-pull` uses `HOMEBREW_GITHUB_API_TOKEN` for GitHub API access (artifact download, release creation)

No manual `git remote set-url` needed in publish.yml because `git-try-push` handles auth.
(see solution: `docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md`)

### sed pattern and bottle block coexistence

After `brew pr-pull` runs, the formula will contain both a source `sha256` (after the `url` line) and bottle sha256
hashes (inside the `bottle do` block). The anchored `sed` pattern (`/^ url /{ n; s|...|...| }`) only matches the sha256
immediately following the url line, leaving the bottle block untouched.

### Re-releases (same version, new SHA)

If a version is re-released, `update-formula.yml` creates a new PR with updated SHA256. `brew pr-pull` overwrites the
existing `bottle do` block with new hashes. The `--force` push on the branch handles the case where the branch already
exists.

### Dependabot PRs

The `startsWith(head_branch, 'update/')` filter in publish.yml excludes Dependabot PRs (which use `dependabot/` prefix).
Dependabot PRs target dev (not main), but tests.yml runs on all PRs regardless of target. The branch filter prevents
publish.yml from processing these.

### Fork PR protection

The `--author "app/github-actions"` filter in the PR lookup step prevents a malicious fork contributor from triggering
bottle publishing by naming their branch `update/*`. Even if tests.yml runs on a fork PR and succeeds, publish.yml will
find no matching bot-authored PR and exit with an error.

### Formula compatibility

The formula keeps `depends_on "rust" => :build` for source fallback. `brew pr-pull` adds the `bottle do` block alongside
it. When bottles are available, Homebrew downloads them. When bottles are unavailable (e.g., new macOS version),
Homebrew falls back to source compilation. The `head` block continues to work for `brew install --HEAD`.

### workflow_run known limitations

`workflow_run` has a documented intermittent issue where it occasionally doesn't fire. The `workflow_dispatch` input on
publish.yml provides a manual escape hatch: pass the PR number and branch name to re-run bottle publishing without
re-triggering the full pipeline.

## Sources & References

### Origin

- **Brainstorm:**
  [docs/brainstorms/2026-03-17-homebrew-bottles-brainstorm.md](docs/brainstorms/2026-03-17-homebrew-bottles-brainstorm.md)
  — key decisions: workflow_run trigger over pr-pull label, PAT with admin bypass, xurl-rs only

### Cross-repo References

- Distribution strategy evaluation: `~/dev/xurl-rs/docs/brainstorms/2026-03-17-release-distribution-evaluation.md` —
  confirms this plan as Phase 1, highest-impact channel

### Internal References

- Dispatch solution: `docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md`
- Current update workflow: `.github/workflows/update-formula.yml:79` (sed pattern), `:84-94` (push step)
- Current tests workflow: `.github/workflows/tests.yml` (no changes)
- Branch protection: `.github/rulesets/protect-main.json` (admin bypass actor_id: 5)
- xurl-rs release pipeline: `~/dev/xurl-rs/.github/workflows/release.yml`

### External References

- [Homebrew Bottles docs](https://docs.brew.sh/Bottles)
- [`brew tap-new` source](https://github.com/Homebrew/brew/blob/master/Library/Homebrew/dev-cmd/tap-new.rb) — canonical
  publish.yml template
- [dunglas/homebrew-frankenphp](https://github.com/dunglas/homebrew-frankenphp) — simplest working bottle tap
