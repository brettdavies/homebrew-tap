---
title: "Homebrew setup-homebrew post cleanup fails with exit code 5 when extraheader already unset"
category: workflow-issues
date: 2026-03-19
tags: [github-actions, homebrew, setup-homebrew, post-cleanup, git-config, extraheader, exit-code-5, set-euo-pipefail, publish-workflow]
severity: medium
affected_components: [".github/workflows/publish.yml", "Homebrew/actions/setup-homebrew"]
---

# Homebrew setup-homebrew post cleanup fails with exit code 5

## Problem

`publish.yml` marks workflow runs as failed (exit code 5) during the "Post Set up Homebrew"
cleanup phase, despite all 11 functional steps succeeding. The entire run shows
`conclusion: failure`, creating false-failure noise in the Actions tab.

## Symptom

```text
publish  Post Set up Homebrew  Reset tap symlink.
publish  Post Set up Homebrew  ##[error]The process '/bin/bash' failed with exit code 5
```

All prior steps -- bottle download, upload to source repo, `brew pr-pull`, git push,
PR close, branch delete -- complete successfully.

## Root Cause

The "Push commits" step ran a credential-cleanup preamble that included:

```bash
git config --global --unset-all http.https://github.com/.extraheader 2>/dev/null || true
```

This successfully removes the global `extraheader` entry that `Homebrew/actions/setup-homebrew`
configured during job init. The `|| true` masks the operation within the step itself.

However, `setup-homebrew`'s `post.sh` cleanup runs later under `set -euo pipefail`:

```bash
if [[ -n "${STATE_TOKEN_SET-}" ]]; then
  git config --global --unset-all "http.${GITHUB_SERVER_URL}/.extraheader"
  echo "Removed token."
fi
```

Because the key was already removed, `git config --unset-all` returns **exit code 5**
(key not found). Under `set -e`, this is fatal.

**Key fact:** `git config --unset-all` returns exit code 5 when the key doesn't exist:

```bash
$ git config --global --unset-all http.https://nonexistent/.extraheader
$ echo $?
5
```

## Solution

Remove the global unset line from the "Push commits" step. Keep the local unset.
The `git remote set-url` with an embedded PAT is sufficient for push authentication --
the global `extraheader` does not need to be manually cleared because `setup-homebrew`'s
own cleanup handles it.

**Before:**

```yaml
run: |
  git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
  git config --global --unset-all http.https://github.com/.extraheader 2>/dev/null || true
  git config --local --unset-all credential.helper 2>/dev/null || true
  git remote set-url origin "https://x-access-token:${CI_RELEASE_TOKEN}@github.com/${{ github.repository }}.git"
  git checkout main
  git push origin main
```

**After:**

```yaml
run: |
  git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
  git config --local --unset-all credential.helper 2>/dev/null || true
  git remote set-url origin "https://x-access-token:${CI_RELEASE_TOKEN}@github.com/${{ github.repository }}.git"
  git checkout main
  git push origin main
```

## Verification

1. **Local:** `git config --global --unset-all` on a nonexistent key returns exit code 5
2. **Post-fix:** Next `publish.yml` run should show "Removed token." in Post Set up Homebrew
   logs and `conclusion: success`
3. **Auth:** The `git push` still succeeds -- embedded PAT in the remote URL provides
   authentication independently of the global extraheader

## Prevention

- **Never manually remove git config keys set by a third-party action.** If an action sets
  a global config entry during its main step, its `post` phase will clean it up. Removing it
  yourself creates a situation where the action's cleanup fails on a missing key.
- **Audit workflow steps for overlapping config mutations.** Before adding `git config --global
  --unset`, check whether any action in the workflow touches the same key.
- **If you must remove a key defensively, guard against exit code 5.** Use
  `git config --global --unset-all <key> || true` or check existence first.
- **Prefer scoped overrides over global unsets.** Use `git -c <key>=<value> <command>` for
  per-command overrides rather than mutating global state.

## Key Insight

Global git config in CI is shared mutable state across action lifecycles. If you did not set
a config key, do not unset it -- the action that set it owns its cleanup, and pre-empting
that cleanup turns a benign absence into a fatal error under strict shell modes.

## Related Documentation

- [Automated Homebrew Formula Updates via repository_dispatch][dispatch]
  -- credential destruction by setup-homebrew
- [Automated Homebrew Bottle Publishing Pipeline][bottles]
  -- full CI/CD pipeline and bottling workflow
- [GitHub Ruleset mergeStateStatus BLOCKED for Bypass Actors][blocked]
  -- related false-status pattern
- [Homebrew/actions/setup-homebrew post.sh][post-sh]
  -- upstream cleanup script

[dispatch]: ../integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md
[bottles]: ../integration-issues/homebrew-bottle-publishing-pipeline-20260317.md
[blocked]: github-ruleset-merge-state-blocked-bypass-actors-20260318.md
[post-sh]: https://github.com/Homebrew/actions/blob/main/setup-homebrew/post.sh

- Failed run: <https://github.com/brettdavies/homebrew-tap/actions/runs/23315299375/job/67813053032>
- Fix PR: <https://github.com/brettdavies/homebrew-tap/pull/22>
