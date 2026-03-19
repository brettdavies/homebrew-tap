---
title: "gh CLI fine-grained PAT missing OAuth scopes"
date: 2026-03-18
problem_type: workflow_issue
component: gh_cli_auth
severity: low
resolution_type: config_change
root_cause: fine_grained_pat_missing_account_scope
tags:
  - gh-cli
  - github-auth
  - oauth-scopes
  - fine-grained-pat
affected_components:
  - "gh CLI authentication"
  - "GitHub fine-grained PAT"
resolution_time: "< 5 minutes"
---

# gh CLI Fine-Grained PAT Missing OAuth Scopes

## Problem

`gh api user/starred/<owner>/<repo> -X PUT` returned HTTP 403:
`"Resource not accessible by personal access token"`. The `gh` CLI
was authenticated as the correct user (`brettdavies`) with a
fine-grained PAT (`github_pat_...`), but the token lacked the
account-level scope needed for the starring API.

## Root Cause

Fine-grained PATs have granular permissions separated into
**repository permissions** and **account permissions**. The starring
API (`PUT /user/starred/{owner}/{repo}`) requires account-level
access, not repo-level access. The token had repo permissions but
was missing the **Starring** account permission.

The `gh` CLI's OAuth layer can add scopes via `gh auth refresh`,
which triggers a device-code OAuth flow that supplements the
token's capabilities.

## Solution

```bash
gh auth refresh -h github.com -s read:user
```

This triggers the GitHub device-code OAuth flow. After completing
the browser authorization, the CLI gains the `read:user` scope
which includes starring access. The starring API call then succeeds:

```bash
# Returns HTTP 204 (no output = success)
gh api user/starred/<owner>/<repo> -X PUT -H "Content-Length: 0"
```

Key flags:

- `-h github.com` — required when running non-interactively
  (Claude Code / CI environments)
- `-s read:user` — the OAuth scope that covers starring and other
  account-level read operations

## Prevention

- When `gh api` returns 403 with "Resource not accessible by
  personal access token", check whether the endpoint is
  account-level (not repo-level)
- Run `gh auth status` to confirm which token is active
- Account-level GitHub API endpoints (starring, following,
  user settings) require OAuth scopes beyond what fine-grained
  PATs provide by default
