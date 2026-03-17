---
module: System
date: 2026-03-17
problem_type: workflow_issue
component: development_workflow
symptoms:
  - "guard-main-docs.yml blocks PRs to main that include docs/plans/, docs/solutions/, or docs/brainstorms/"
  - "Engineering docs on dev must never be lost but must never reach main"
  - "Direct merge from dev to main fails CI because dev contains guarded doc paths"
root_cause: missing_workflow_step
resolution_type: workflow_improvement
severity: high
tags: [release-branch, guard-main-docs, dev-to-main, engineering-docs, workflow, cross-repo]
---

# Release Branch Pattern for Guarded Engineering Docs

## Problem

All brettdavies repos use a `guard-main-docs.yml` CI workflow that blocks `docs/plans/`, `docs/solutions/`, and `docs/brainstorms/` from reaching `main`. These engineering docs live exclusively on `dev`. When it's time to merge dev to main, a direct PR fails CI. The procedure for safely creating a release branch — removing docs without losing them — is critical and must be followed exactly.

## Environment

- Applies to: all brettdavies repos with `guard-main-docs.yml`
- Current repos: `homebrew-tap`, `xurl-rs`, `bird`
- Date: 2026-03-17

## Symptoms

- PR from dev to main fails `check-forbidden-docs` status check
- Engineering docs must be stripped from the release branch but preserved on dev
- Files on dev that don't exist on main (formula versions, configs) can silently regress if not checked

## What Didn't Work

**Merging dev directly to main:** Fails `guard-main-docs.yml` because dev contains `docs/plans/`, `docs/solutions/`, and `docs/brainstorms/`.

**Deleting docs on dev before merging:** Destroys the engineering knowledge base. Docs must remain on dev permanently.

**Using `rm` or `git rm` for deletion:** Both are denied in `settings.json` across all brettdavies repos. Must use `gio trash` (safe deletion to system trash).

## Solution

### Step-by-step release branch procedure

```bash
# 1. Start from dev
git checkout dev
git pull origin dev

# 2. Create release branch
git checkout -b release/<name> dev

# 3. Check for file divergence between release branch and main
#    CRITICAL: catch regressions before they reach main
git diff origin/main --stat

# 4. Restore any files where main is ahead of dev
#    (e.g., formula files updated by CI on main but not on dev)
git checkout origin/main -- <files-where-main-is-ahead>
git commit -m "chore: restore files from main to avoid regression"

# 5. Remove guarded docs (safe deletion to trash)
gio trash docs/brainstorms docs/plans docs/solutions

# 6. Stage the deletions
git add -u

# 7. Commit
git commit -m "chore: remove engineering docs for main merge"

# 8. Verify only intended changes remain
git diff origin/main --stat

# 9. Push and create PR
git push -u origin release/<name>
gh pr create --title "<type>(scope): description" --base main --head release/<name>
```

### Critical checkpoints

| Step | What to verify | Why |
|------|---------------|-----|
| Step 3 | `git diff origin/main --stat` shows only expected files | Catches unintended regressions (e.g., formula downgrade from v1.0.4 to v1.0.3) |
| Step 4 | Restore files where main has newer content | Prevents overwriting CI-managed files (formulas, generated configs) |
| Step 8 | Final diff contains only your intended changes, no docs paths | Ensures guard-main-docs will pass |

### The status filter (guard-main-docs.yml)

The guard workflow must filter by file status to allow doc **deletions** on release branches while still blocking **additions/modifications**:

```javascript
const forbidden = files
  .filter(f => f.status === 'added' || f.status === 'modified')
  .map(f => f.filename)
  .filter(f =>
    f.startsWith('docs/plans/') ||
    f.startsWith('docs/solutions/') ||
    f.startsWith('docs/brainstorms/')
  );
```

Without `.filter(f => f.status === 'added' || f.status === 'modified')`, even removing docs from the release branch would trigger the guard (the files appear in the PR diff as "removed").

## Why This Works

The release branch is a short-lived fork of dev that exists solely to strip engineering docs before merging to main. The docs remain on dev (the authoritative source). The release branch is deleted after the PR merges. This preserves the invariant: engineering docs live on dev only, production code lives on main only.

The file divergence check (Step 3-4) catches a subtle issue: when CI workflows update files directly on main (e.g., `brew pr-pull` updating formulas), those changes don't exist on dev. Without restoring them, the release branch would regress main to dev's older version.

## Prevention

1. **Always use this procedure** when merging dev to main in repos with `guard-main-docs.yml`. Never attempt a direct PR from dev to main.

2. **Always check `git diff origin/main --stat`** before and after doc removal. The first check catches divergence; the second confirms only intended changes remain.

3. **Never use `rm` or `git rm`** for file deletion. Use `gio trash` then `git add -u`. This is enforced by `settings.json` across all brettdavies repos.

4. **Ensure guard-main-docs.yml has the status filter.** All three repos (homebrew-tap, xurl-rs, bird) must include `.filter(f => f.status === 'added' || f.status === 'modified')`. Without it, release branches cannot pass the guard.

5. **For destructive branch operations** (resets, rebases), run the full file inventory protocol first. See xurl-rs `docs/solutions/branch-reset-file-inventory.md`.

## Related Issues

- See also: [xurl-rs branch-reset-file-inventory](https://github.com/brettdavies/xurl-rs/blob/dev/docs/solutions/branch-reset-file-inventory.md) -- recovery when files are lost during branch sync
- See also: [homebrew-bottle-publishing-pipeline](./homebrew-bottle-publishing-pipeline-20260317.md) -- first use of this pattern for the bottles release
- See also: [homebrew-tap-automated-formula-updates-via-dispatch](./homebrew-tap-automated-formula-updates-via-dispatch.md) -- CI infrastructure that creates the dev/main divergence
