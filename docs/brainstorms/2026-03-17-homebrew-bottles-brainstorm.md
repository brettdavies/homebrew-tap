# Brainstorm: Homebrew Bottles for Fast Installs

**Date:** 2026-03-17
**Status:** Final
**Trigger:** Installing xurl-rs requires 472MB of dependency downloads (llvm 368MB, rust 102MB) and 2GB of installed files — all for a 4.5MB binary.

## What We're Building

Add **Homebrew Bottles** to the tap so `brew install` downloads a ~3MB pre-compiled bottle instead of compiling from source. The formula stays unchanged — CI builds bottles and `brew pr-pull` adds the `bottle do` block automatically.

## Full Release Pipeline (Tag to Install)

When a version tag is pushed to xurl-rs:

```text
git tag v1.0.5 && git push --tags
  → source repo release.yml:
    → build (cross-platform binaries)
    → publish (crates.io via Trusted Publishing)
    → release (GitHub Release with binaries)
    → homebrew (repository_dispatch to homebrew-tap)
  → homebrew-tap:
    → update-formula.yml creates PR with new version + SHA256
    → tests.yml builds bottles on 3 runners, uploads artifacts
    → publish.yml (workflow_run trigger) runs brew pr-pull
      → uploads bottles to GitHub Release on tap repo
      → adds bottle do block to formula
      → pushes directly to main (PR auto-closes)
```

**Zero manual steps.** Tag push triggers everything.

### xurl-rs (source repo)

Already complete. `release.yml` has all 4 jobs: build, publish (crates.io), release (GitHub Release), homebrew (repository_dispatch). No changes needed.

### homebrew-tap (this repo) — the only changes needed

**1. `update-formula.yml`** — change `git push origin main` to `gh pr create`. ~5 lines changed.

**2. `publish.yml`** — new file, ~35 lines. Triggered by `workflow_run` on tests.yml completion (not the standard `pr-pull` label pattern). This eliminates the label, the auto-label workflow, and all manual steps.

**3. `tests.yml`** — no changes. Already builds bottles and uploads artifacts on PRs.

**4. Formulas** — no manual changes. `brew pr-pull` adds the `bottle do` block automatically.

## Key Decisions

### 1. workflow_run trigger instead of pr-pull label

The standard `brew tap-new` scaffold uses a `pr-pull` label to trigger publishing. Most taps apply this label manually. We skip the label entirely by using `workflow_run`:

```yaml
on:
  workflow_run:
    workflows: ["brew test-bot"]
    types: [completed]
```

This fires when tests.yml completes. publish.yml checks `conclusion == 'success'` and `event == 'pull_request'`, then runs `brew pr-pull` with the PR number from `workflow_run.pull_requests[0].number`.

**Trade-off:** Deviates from the standard Homebrew pattern. But the standard pattern requires manual labeling — every tap surveyed either labels manually or adds a separate auto-label workflow. Using `workflow_run` directly is simpler (one file instead of two) and fully automated.

**Caveat:** `workflow_run.pull_requests` is only populated for same-repo branches (not cross-fork PRs). This is fine — all PRs are created by the bot in the same repo.

### 2. Direct push to main via PAT

`brew pr-pull` pushes directly to main (standard Homebrew behavior — the PR is closed, not merged). publish.yml must use `HOMEBREW_TAP_TOKEN` (PAT with admin bypass), not `github.token`, to bypass branch protection.

### 3. publish.yml must be on main before first use

`workflow_run` (like `pull_request_target`) runs the workflow as defined on the **default branch**. publish.yml must be merged to main before any bottle PR can trigger it.

## CI Structure Changes

| Workflow | Current | After |
|----------|---------|-------|
| update-formula.yml | Pushes directly to main | Creates PR to main |
| tests.yml | Builds bottles + uploads artifacts | No changes |
| publish.yml | Does not exist | New: `workflow_run` trigger, runs `brew pr-pull` |

**Total new YAML: ~35 lines. Total changed YAML: ~5 lines.**

## Bootstrap Sequence

1. PR the updated `update-formula.yml` and new `publish.yml` from dev to main via release branch
2. Trigger xurl-rs release (or manually dispatch `update-formula.yml`)
3. Verify: PR created → bottles built → published → PR closed

## Resolved Questions

1. **Auto-labeling:** Eliminated. `workflow_run` replaces the label-based trigger entirely.
2. **Bottle storage:** Non-issue. GitHub Releases have no storage limits for public repos.
3. **Fallback:** If bottles aren't available for a platform, Homebrew falls back to source compilation automatically. Acceptable.
4. **Runner matrix:** `ubuntu-22.04`, `macos-15-intel`, `macos-26` matches the current `brew tap-new` template. No changes.
5. **Crates.io:** Already automated in xurl-rs via Trusted Publishing. No tap-side changes needed.

## References

- [Homebrew Bottles docs](https://docs.brew.sh/Bottles)
- [`brew tap-new` source (tap-new.rb)](https://github.com/Homebrew/brew/blob/master/Library/Homebrew/dev-cmd/tap-new.rb) — canonical templates
- [dunglas/homebrew-frankenphp](https://github.com/dunglas/homebrew-frankenphp) — simplest working bottle tap (2 files, 82 lines)
- [chenasraf/homebrew-tap](https://github.com/chenasraf/homebrew-tap) — repository_dispatch + bottles (3 files, 145 lines)
- Prior art: `alternative-approaches.md` in this repo's skill references
- xurl-rs release.yml — existing 4-job pipeline (build, publish, release, homebrew)
