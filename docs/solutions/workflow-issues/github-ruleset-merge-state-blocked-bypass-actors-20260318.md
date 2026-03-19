---
title: "GitHub Ruleset mergeStateStatus BLOCKED for Bypass Actors"
date: 2026-03-18
problem_type: workflow_issue
component: github_rulesets
severity: medium
resolution_type: documentation
root_cause: github_api_misleading_merge_state
tags:
  - github-rulesets
  - merge-state
  - bypass-actor
  - protect-main
  - github-api
affected_components:
  - ".github/rulesets/protect-main.json"
  - "GitHub ruleset: Protect main (update rule)"
  - "GitHub GraphQL / REST PR merge state API"
resolution_time: "< 1 hour"
---

# GitHub Ruleset `mergeStateStatus: BLOCKED` for Bypass Actors

## Problem

GitHub PR #18 on `brettdavies/homebrew-tap` showed
`mergeStateStatus: BLOCKED` in the API and UI, despite all required
status checks passing and ruleset configuration being correct.

Symptoms observed:

- `gh pr view` showed `mergeStateStatus: BLOCKED`
- GraphQL API confirmed `mergeStateStatus: BLOCKED` with
  `statusCheckRollup.state: SUCCESS`
- REST API showed `mergeable_state: blocked`
- `required_approving_review_count` was 0, commits were signed,
  branch was up to date

## Investigation

1. **PR status** (`gh pr view 18 --json mergeStateStatus,mergeable`)
   — confirmed `BLOCKED`, `MERGEABLE`
2. **Active rulesets** (`gh api repos/.../rules/branches/main`)
   — matched local `protect-main.json` exactly
3. **Legacy branch protection**
   (`gh api repos/.../branches/main/protection`) — 404, none existed
4. **Branch currency** — PR branch was 0 commits behind `main`,
   2 ahead
5. **Commit signatures** — both commits `verified` / `valid`
6. **GraphQL `isRequired` check** — `lint` required+success,
   `check-forbidden-docs` required+success, `bottles` not required
   (skipped)
7. **`statusCheckRollup.state`** — `SUCCESS`
8. **Direct merge attempt**
   (`gh api .../pulls/18/merge -X PUT -f merge_method=squash`)
   — HTTP 200 SUCCESS

## Root Cause

GitHub's `mergeStateStatus` field evaluates merge eligibility from
the perspective of a **non-bypass user**. The `protect-main` ruleset
includes an `update` rule, which prevents non-privileged actors from
pushing to `main`. The merge-state evaluator treats this as a block
signal regardless of whether the requester holds bypass permissions.

The bypass actor (`actor_id: 5`, `actor_type: RepositoryRole`,
`bypass_mode: always`) is the repo owner's admin role. This bypass
is fully honored by GitHub's merge machinery but **not reflected in
`mergeStateStatus`**. The field reports the worst-case non-bypass
state.

This is consistent with known GitHub behavior on personal repos:
`Integration` actor bypass is unavailable (org-only), so the only
bypass path is via the owner's admin role, which is invisible to the
status field.

## Solution

The merge was never actually blocked. Bypass actors can merge despite
the `BLOCKED` label. Attempt the merge directly via the API:

```bash
gh api repos/brettdavies/homebrew-tap/pulls/<PR_NUMBER>/merge \
  -X PUT \
  -f merge_method=squash
```

HTTP 200 confirms success.

### Recommended fix: remove the `update` rule

The `update` rule overlaps with `non_fast_forward` (blocks force
pushes) and `pull_request` (requires a PR for all changes). Removing
it eliminates the `BLOCKED` confusion with no security regression:

| Rule | Purpose | Still present |
|---|---|---|
| `pull_request` | Require PR + squash-only | Yes |
| `non_fast_forward` | Block force pushes | Yes |
| `required_signatures` | GPG signing | Yes |
| `required_status_checks` | CI must pass | Yes |
| `required_linear_history` | Linear history | Yes |
| `creation` | Prevent branch creation | Yes |
| `deletion` | Prevent branch deletion | Yes |

## Diagnostic Checklist

When a merge appears blocked, run these steps in order:

### Step 1: Is this the known `update` rule false alarm?

```bash
gh api repos/brettdavies/homebrew-tap/rulesets \
  --jq '.[] | select(.name == "Protect main") | .rules[].type'
```

If `update` appears AND your actor has bypass, the `BLOCKED` status
is the known false alarm.

### Step 2: Are required status checks passing?

```bash
gh pr checks <PR_NUMBER> --repo brettdavies/homebrew-tap
```

Both `lint` and `check-forbidden-docs` must show success.

### Step 3: GraphQL deep check with `isRequired`

```graphql
query {
  repository(owner: "brettdavies", name: "homebrew-tap") {
    pullRequest(number: <NUMBER>) {
      mergeStateStatus
      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              state
              contexts(first: 20) {
                nodes {
                  ... on CheckRun {
                    name
                    conclusion
                    isRequired(pullRequestNumber: <NUMBER>)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

### Step 4: Verify bypass actor configuration

```bash
gh api repos/brettdavies/homebrew-tap/rulesets \
  --jq '.[] | select(.name == "Protect main") | .bypass_actors'
```

Expect:
`[{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]`

## Prevention

- When `mergeStateStatus: BLOCKED` with all checks green, check
  bypass actor config before investigating further
- Consider removing the `update` rule from `protect-main.json` to
  eliminate the false alarm entirely
- Use `gh api .../pulls/<N>/merge -X PUT` to get ground truth —
  HTTP 200 = success

## Related

- [Release branch pattern for guarded docs](
  ./release-branch-pattern-for-guarded-docs-20260317.md) — same
  `protect-main` ruleset, bypass actor patterns
- [Homebrew bottle publishing pipeline](
  ../integration-issues/homebrew-bottle-publishing-pipeline-20260317.md)
  — `git-try-push` uses PAT with admin bypass to push to main
- `.github/rulesets/protect-main.json` — source of truth for the
  ruleset
