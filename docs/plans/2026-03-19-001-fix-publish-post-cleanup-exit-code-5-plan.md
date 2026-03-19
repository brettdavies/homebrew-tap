---
title: "fix(ci): publish.yml Post Set up Homebrew cleanup fails with exit code 5"
type: fix
status: active
date: 2026-03-19
---

# fix(ci): publish.yml Post Set up Homebrew cleanup fails with exit code 5

## Overview

The `publish.yml` workflow marks runs as **failed** even though all 11 business-logic
steps succeed. The failure occurs in the auto-generated "Post Set up Homebrew"
cleanup step (exit code 5), caused by a conflict between our credential-clearing
code and the Homebrew action's own post-job cleanup.

**CI run:** <https://github.com/brettdavies/homebrew-tap/actions/runs/23315299375/job/67813053032>

## Problem Statement

### Symptom

```text
publish  Post Set up Homebrew  Reset tap symlink.
publish  Post Set up Homebrew  ##[error]The process '/bin/bash' failed with exit code 5
```

The entire workflow run is marked `conclusion: failure` despite every functional
step (download artifacts, upload bottles, update formula, push commits, close PR,
delete branch) completing successfully.

### Root Cause

**Step interaction conflict:** Our "Push commits" step proactively clears the
global git extraheader that `Homebrew/actions/setup-homebrew` set during job init:

```bash
# In our "Push commits" step (publish.yml:132-133)
git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
git config --global --unset-all http.https://github.com/.extraheader 2>/dev/null || true  # <-- THIS
```

Later, the Homebrew action's [post.sh](https://github.com/Homebrew/actions/blob/main/setup-homebrew/post.sh)
cleanup runs:

```bash
# In Homebrew/actions/setup-homebrew/post.sh (runs under set -euo pipefail)
if [[ -n "${STATE_TOKEN_SET-}" ]]; then
  git config --global --unset-all "http.${GITHUB_SERVER_URL}/.extraheader"
  echo "Removed token."
fi
```

Since our step already removed the key, `git config --unset-all` returns **exit
code 5** ("key not found"). Under `set -euo pipefail`, this is fatal.

### Verification

Confirmed locally:

```bash
$ git config --global --unset-all http.https://nonexistent/.extraheader
$ echo $?
5
```

## Proposed Solution

Remove the global extraheader unset from our "Push commits" step. Leave it for
the Homebrew action's own cleanup to handle — that's its job.

The `git remote set-url` with PAT is sufficient for authentication. The global
extraheader doesn't need to be removed for the push to succeed — git uses the
remote URL's embedded credentials, and the `--local --unset-all` already removes
any local-scope conflict.

### Before (`publish.yml:128-137`)

```yaml
- name: Push commits
  env:
    CI_RELEASE_TOKEN: ${{ secrets.CI_RELEASE_TOKEN }}
  run: |
    git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
    git config --global --unset-all http.https://github.com/.extraheader 2>/dev/null || true
    git config --local --unset-all credential.helper 2>/dev/null || true
    git remote set-url origin "https://x-access-token:${CI_RELEASE_TOKEN}@github.com/${{ github.repository }}.git"
    git checkout main
    git push origin main
```

### After

```yaml
- name: Push commits
  env:
    CI_RELEASE_TOKEN: ${{ secrets.CI_RELEASE_TOKEN }}
  run: |
    git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
    git config --local --unset-all credential.helper 2>/dev/null || true
    git remote set-url origin "https://x-access-token:${CI_RELEASE_TOKEN}@github.com/${{ github.repository }}.git"
    git checkout main
    git push origin main
```

The only change: remove line 133 (`git config --global --unset-all ...`).

## Technical Considerations

### Will the push still authenticate correctly?

Yes. `git remote set-url` embeds the PAT in the URL. Git resolves credentials
from the remote URL first — the global extraheader is a fallback mechanism set by
`actions/checkout` (and `setup-homebrew`). Keeping it in place doesn't interfere;
removing it is unnecessary.

### Could the global extraheader conflict with the PAT?

No. The extraheader contains the `GITHUB_TOKEN` (repo-scoped), while the remote
URL uses `CI_RELEASE_TOKEN` (cross-repo PAT). Git uses the remote URL's embedded
credentials over the extraheader when both are present. The push already works
correctly with both in place (as evidenced by the successful push in the failed
run).

### Does this affect other workflows?

No. Only `publish.yml` has the "Push commits" step that clears global git config.
`tests.yml` and `update-formula.yml` don't push directly and don't touch git
config.

## Acceptance Criteria

- [x] Remove the global extraheader unset line from `publish.yml`
- [ ] Trigger a test run to confirm:
  - All functional steps still pass
  - "Post Set up Homebrew" cleanup succeeds (logs show "Removed token.")
  - Overall workflow conclusion is `success`

## Success Metrics

- `publish.yml` runs show `conclusion: success` when all functional steps pass
- No more false-failure noise in the Actions tab

## Dependencies & Risks

**Risk:** None. The global extraheader was being removed as a defensive measure
but isn't needed — the Homebrew action's cleanup handles it. The fix is a single
line removal with clear causation chain.

## Sources & References

- **Failed run:** <https://github.com/brettdavies/homebrew-tap/actions/runs/23315299375/job/67813053032>
- **Homebrew post.sh:** <https://github.com/Homebrew/actions/blob/main/setup-homebrew/post.sh>
- **git-config docs:** `git config --unset-all` returns exit code 5 when key is absent
- **publish.yml:** `.github/workflows/publish.yml:128-137`
