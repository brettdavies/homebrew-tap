---
title: Repository Security Hardening
type: chore
status: completed
date: 2026-03-16
origin: docs/brainstorms/2026-03-16-repo-security-hardening-brainstorm.md
---

# chore: Repository Security Hardening

## Enhancement Summary

**Deepened on:** 2026-03-16
**Agents used:** security-sentinel, architecture-strategist, code-simplicity-reviewer,
best-practices-researcher (GitHub API), skill-reference-explorer

### Critical Discovery

`github-actions[bot]` **cannot bypass rulesets via `GITHUB_TOKEN`**. The `update-formula.yml`
workflow must use a PAT (not `GITHUB_TOKEN`) for checkout and push to protected `main`. The
existing `HOMEBREW_TAP_TOKEN` secret (fine-grained PAT with `contents:write` scoped to
`brettdavies/homebrew-tap`) already has the required permissions — reuse it for both
`repository_dispatch` (from tool repos) and push-to-main (from `update-formula.yml`).

### Key Improvements

1. Workflow must use PAT for pushing to protected `main` (not `GITHUB_TOKEN`)
2. Add concurrency group to `update-formula.yml` to serialize simultaneous formula updates
3. Mandate download-then-hash as the only pipefail fix (remove `set -euo pipefail` alternative)
4. Formula allowlist must be checked before filesystem operations
5. Add step to verify exact status check context names before applying rulesets
6. Document emergency rollback commands
7. Specify `target-branch: dev` in dependabot.yml

### Simplification Opportunities (User Decision)

The code simplicity reviewer flagged these as potential YAGNI violations. The user explicitly
requested `--repo` and source-controlled configs during brainstorming, so these are preserved
but flagged:

- `--repo` flag: user requested for reusability across repos
- `--dry-run` flag: user requested for safety
- CODEOWNERS: zero enforcement value for solo dev, but serves as documentation
- Idempotent upsert: user requested, but simpler delete-then-create is an option

### API Implementation Details Discovered

- Rulesets: `POST /repos/{owner}/{repo}/rulesets` with `--input` (never inline `-f` for
  nested objects)
- Actions permissions: `PUT .../actions/permissions` +
  `PUT .../actions/permissions/selected-actions` + `PUT .../actions/permissions/workflow`
- Fork PR policy: `PUT .../actions/permissions/fork-pr-contributor-approval` with
  `approval_policy=all_external_contributors`
- Collaborators-only PRs: likely `PATCH` with
  `pull_request_creation_policy=collaborators_only` (unconfirmed, Feb 2026 feature)
- Rule type names differ from UI labels (e.g., `non_fast_forward` = "Block force pushes",
  `creation` = "Restrict creations")

## Overview

Lock down the `brettdavies/homebrew-tap` repository so only the owner (or owner's PATs) can
modify it. All configuration is source-controlled in `.github/` and applied via `gh api`,
following the dotfiles pattern. Manual-only settings are documented in the apply script's
output.

## Problem Statement / Motivation

The homebrew-tap is a public repository (required for Homebrew taps) with zero security
hardening: no rulesets, no PR restrictions, all merge methods enabled, unused features (wiki,
projects, issues) active, and GitHub Actions fully unrestricted. Homebrew formulas are Ruby
files executed during `brew install`, making formula tampering a direct supply chain attack
vector on every user who installs from this tap.

## Proposed Solution

Layered source-controlled configs in `.github/` with an idempotent apply script (see
brainstorm: `docs/brainstorms/2026-03-16-repo-security-hardening-brainstorm.md`).

### New files

| File | Purpose |
| ---- | ------- |
| `.github/rulesets/protect-main.json` | Main branch ruleset (full protection + bot bypass) |
| `.github/rulesets/protect-dev.json` | Dev branch ruleset (signed commits + deletion/force-push protection) |
| `.github/dependabot.yml` | GitHub Actions version updates (weekly) |
| `.github/CODEOWNERS` | Ownership declaration (`* @brettdavies`) |

### Modified files

| File | Change |
| ---- | ------ |
| `.github/workflows/tests.yml` | Pin `actions/cache` and `actions/upload-artifact` to SHA |
| `.github/workflows/update-formula.yml` | Add formula allowlist, `brew audit` step, fix `pipefail` bug, tighten REPO regex |

## Technical Considerations

### CRITICAL: GITHUB_TOKEN cannot bypass rulesets

**Discovery from deepening research:** `github-actions[bot]` cannot bypass rulesets when
pushing via the default `GITHUB_TOKEN`. The `update-formula.yml` workflow currently uses
`GITHUB_TOKEN` for checkout and push. With rulesets protecting `main`, this push will be
rejected.

**Fix:** The workflow must use the existing `HOMEBREW_TAP_TOKEN` PAT for checkout and push.
This fine-grained PAT is already scoped to `brettdavies/homebrew-tap` with `contents: write`
and stored as a repo secret (used by tool repos for `repository_dispatch`). Update the
workflow:

```yaml
- uses: actions/checkout@<sha>
  with:
    token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
# ... (the push will use the same token from the checkout)
```

With a PAT, the push authenticates as the repo owner (not as `github-actions[bot]`). The
`protect-main` ruleset should then grant bypass to the **admin role** (`actor_id: 5`,
`actor_type: "RepositoryRole"`) which covers the owner's PAT. The `github-actions[bot]`
bypass entry in the ruleset can be removed since it's the PAT that does the pushing.

### Ruleset bypass actors (revised)

The `protect-main` ruleset bypass should use:

- `actor_id: 5`, `actor_type: "RepositoryRole"`, `bypass_mode: "always"` — Admin role
  (covers the owner and owner's PATs)

This matches the dotfiles `protect-main.json` pattern exactly. No need for a separate
`github-actions[bot]` Integration bypass since the PAT authenticates as the owner.

### SHA pinning exception

`Homebrew/actions/setup-homebrew@main` stays on `@main` per Homebrew's official
recommendation. All other third-party actions must be pinned to full-length commit SHA.

### Collaborators-only PRs

This is a Feb 2026 GitHub feature. API support is unclear. The apply script should attempt
`gh api repos/{owner}/{repo} -X PATCH -f pull_request_access_level=collaborators` and, if it
fails, print a manual instruction for the UI setting.

### brew audit in update-formula.yml

Adding `brew audit --formula <name>` requires installing Homebrew in the update job. Add
`Homebrew/actions/setup-homebrew@main` as a step before the audit. This increases job runtime
by ~30s but catches malformed Ruby before it lands on main. Important: audit by formula name,
never by file path (see
`docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md`).

### pipefail bug in update-formula.yml (SpecFlow finding)

The current tarball download step pipes `curl | sha256sum`. If `curl` fails (e.g., 404 on a
bad tag), the pipeline silently succeeds because `sha256sum` still exits 0 (hashing the error
page HTML). **Mandate download-then-hash** (two separate commands) as the only fix —
`set -euo pipefail` is fragile and less explicit. Additionally, verify the downloaded file is
a valid gzip archive before hashing:

```yaml
- name: Download tarball and compute SHA256
  run: |
    TARBALL_URL="https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz"
    curl --fail-with-body -sL -o tarball.tar.gz "$TARBALL_URL"
    file tarball.tar.gz | grep -q 'gzip' || { echo "::error::Downloaded file is not a gzip archive"; exit 1; }
    SHA=$(sha256sum tarball.tar.gz | awk '{print $1}')
    echo "SHA256=$SHA" >> "$GITHUB_ENV"
    rm tarball.tar.gz
```

### Tighter REPO validation (SpecFlow finding)

The current regex `^brettdavies/` is too permissive — it allows
`brettdavies/../../malicious`. Tighten to `^brettdavies/[a-zA-Z0-9._-]+$` to reject path
traversal and special characters.

### Concurrency control for update-formula.yml (security sentinel finding)

If two `repository_dispatch` events arrive simultaneously (e.g., both `xurl-rs` and `bird`
release at once), concurrent workflow runs will race on `git push`. Add a concurrency group
to serialize formula updates:

```yaml
concurrency:
  group: update-formula
  cancel-in-progress: false
```

### Validation ordering in update-formula.yml (security sentinel finding)

The formula allowlist must be checked **before** filesystem operations
(`-f "Formula/${FORMULA}.rb"`). The allowlist is the primary security gate; the file existence
check is defense-in-depth. Reorder the validation step:

1. Check allowlist (`^(xurl-rs|bird)$`)
2. Validate version format
3. Validate repo regex
4. Check formula file exists

### Apply script modes

The script should support `--dry-run` (show what would change without applying) and print a
summary after execution. This makes it safe to test and audit before committing to changes.

### Dependabot and collaborators-only PRs

Verify that Dependabot can still open PRs under the "Collaborators only" setting. Dependabot
is a GitHub-native bot and may be treated as a collaborator automatically. If not, the
collaborators-only setting must be applied after confirming Dependabot compatibility, or
Dependabot must be added as a collaborator.

### Apply script idempotency

The script must handle the create-or-update pattern for rulesets:

1. `GET /repos/{owner}/{repo}/rulesets` — list existing rulesets
2. Filter by `name` field to find matches
3. If match found: `PUT /repos/{owner}/{repo}/rulesets/{id}` with updated JSON
4. If no match: `POST /repos/{owner}/{repo}/rulesets` with full JSON

Use `jaq` (not `jq`) per user preferences for JSON processing.

### Ordering dependencies

1. Rulesets must be applied **after** the workflows are committed and passing — otherwise
   status check requirements will block the initial merge
2. The `protect-main` PR requirement must grant bot bypass **before** the next
   `repository_dispatch` fires — otherwise the bot push will be rejected
3. The apply script should be committed and merged to `main` before being run, so it's
   source-controlled at the time of application

**Recommended sequence:**

1. Verify `HOMEBREW_TAP_TOKEN` secret exists on `brettdavies/homebrew-tap` (fine-grained
   PAT with `contents: write` — already provisioned)
2. Commit all new files and workflow changes to `dev`
3. PR `dev` -> `main`, merge (gets all files on `main` and validates workflows pass)
4. Verify exact status check context names from the CI run:
   `gh api repos/brettdavies/homebrew-tap/commits/{sha}/check-runs --jq '.check_runs[].name'`
   — update `protect-main.json` if names differ
5. Run `apply-repo-settings.sh --dry-run` to preview changes
6. Run `apply-repo-settings.sh` to apply repo settings, Actions permissions, then rulesets
7. Apply collaborators-only PR setting (API or manual)
8. Verify with a test `workflow_dispatch` of `update-formula.yml`
9. Verify Dependabot opens its first PR within 1 week

**Emergency rollback:** If rulesets block all merges, delete the ruleset immediately:

```bash
# List rulesets to find the ID
gh api repos/brettdavies/homebrew-tap/rulesets --jq '.[] | "\(.id) \(.name)"'
# Delete the blocking ruleset
gh api repos/brettdavies/homebrew-tap/rulesets/{id} -X DELETE
```

## Acceptance Criteria

### Phase 1: Source-Controlled Configs

- [x] `.github/rulesets/protect-main.json` — rules: restrict creations, restrict updates,
  restrict deletions, block force pushes, require PR (0 approvals, squash only), require
  signed commits, require status checks (exact names from CI run), require linear history;
  bypass: admin role only (Integration bypass not supported on personal repos)
- [x] `.github/rulesets/protect-dev.json` — rules: restrict deletions, block force pushes,
  require signed commits; bypass: admin role
- [x] `.github/dependabot.yml` — `github-actions` ecosystem, weekly, `build(deps)` commit
  prefix, `target-branch: dev`
- [x] `.github/CODEOWNERS` — `* @brettdavies`

### Phase 2: Apply Repo Settings (applied directly via `gh api`)

- [x] Repo settings: disable wiki, projects, issues; merge + squash merges; auto-delete
  branches
- [x] Actions permissions: restrict to `actions/*` and `Homebrew/*`; default token read-only;
  disable "create and approve PRs"
- [x] Fork PR policy: require approval for all outside collaborators
- [x] Rulesets created from JSON files (`protect-main` id:13978435, `protect-dev` id:13978421)
- [ ] Collaborators-only PR setting: API not available; set manually in Settings > General >
  Pull Requests

### Phase 3: Workflow Hardening

- [x] `tests.yml`: `actions/cache@v4` pinned to current SHA with version comment
- [x] `tests.yml`: `actions/upload-artifact@v4` pinned to current SHA with version comment
- [x] `update-formula.yml`: use `HOMEBREW_TAP_TOKEN` for checkout and push (not
  `GITHUB_TOKEN`)
- [x] `update-formula.yml`: add concurrency group (`update-formula`,
  `cancel-in-progress: false`)
- [x] `update-formula.yml`: fix `pipefail` bug — download tarball to file, verify gzip,
  then hash
- [x] `update-formula.yml`: reorder validation — allowlist first, then version, then repo
  regex, then file exists
- [x] `update-formula.yml`: tighten REPO regex to `^brettdavies/[a-zA-Z0-9._-]+$`
- [x] `update-formula.yml`: formula allowlist validation step (`xurl-rs`, `bird`)
- [x] `update-formula.yml`: `Homebrew/actions/setup-homebrew@main` added for brew
  availability
- [x] `update-formula.yml`: `brew audit --formula "${FORMULA}"` step added after sed update,
  before commit

### Phase 4: Apply and Verify

- [ ] Verify `HOMEBREW_TAP_TOKEN` secret exists on `brettdavies/homebrew-tap` (fine-grained
  PAT, `contents: write` — already provisioned)
- [ ] Verify exact status check context names from CI run; update `protect-main.json` if
  needed
- [ ] Run `apply-repo-settings.sh --dry-run` against `brettdavies/homebrew-tap`
- [ ] Run `apply-repo-settings.sh` against `brettdavies/homebrew-tap`
- [ ] `gh api repos/brettdavies/homebrew-tap/rulesets` returns two active rulesets
- [ ] Repo settings match desired state (wiki off, issues off, projects off, squash-only)
- [ ] Actions permissions restricted (not "all allowed")
- [ ] Default workflow permissions set to read-only
- [ ] Manual steps (if any) documented and completed
- [ ] Test: verify non-collaborator cannot create PR (if possible to test)
- [ ] Test: verify `workflow_dispatch` of `update-formula.yml` pushes successfully with
  `HOMEBREW_TAP_TOKEN`
- [ ] Test: verify `update-formula.yml` rejects unknown formula names

## Success Metrics

- All 14 gaps in the brainstorm's "Current State" table are resolved
- `gh api repos/brettdavies/homebrew-tap/rulesets` returns two active rulesets
- `gh api repos/brettdavies/homebrew-tap --jq .has_wiki` returns `false`
- `gh api repos/brettdavies/homebrew-tap/actions/permissions` shows restricted actions and
  read-only default
- Pushing directly to `main` (without bot bypass) is rejected
- `update-formula.yml` rejects unknown formula names

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
| ---- | ---------- | ------ | ---------- |
| `HOMEBREW_TAP_TOKEN` PAT scoped wrong or expired | Low | High (bot pushes blocked) | Verify permissions before applying rulesets; test with `workflow_dispatch` immediately after |
| Status check name mismatch in ruleset | Medium | High (blocks all merges to main) | Verify exact check names from CI run before applying rulesets; emergency rollback documented |
| Collaborators-only PR API doesn't exist yet | Medium | Low (fall back to UI) | Script prints manual instruction |
| `brew audit` fails on valid formula | Low | Medium (blocks automated updates) | Run `brew audit` locally first |
| Concurrent formula updates race on git push | Low | Medium (second push fails) | Concurrency group serializes runs |
| Partial script failure leaves inconsistent state | Low | Medium | Script applies settings independently; re-running fixes partial state |
| Dependabot blocked by collaborators-only PRs | Low | Medium | Verify Dependabot compatibility before applying; Dependabot is likely treated as a collaborator natively |
| Removing rulesets drops all protection instantly | Low | High | Emergency rollback commands documented in plan |

**Dependency:** Current SHA hashes for `actions/cache@v4` and `actions/upload-artifact@v4`
must be looked up at implementation time (they may update between planning and
implementation).

## Sources & References

### Origin

- **Brainstorm document:**
  [docs/brainstorms/2026-03-16-repo-security-hardening-brainstorm.md](docs/brainstorms/2026-03-16-repo-security-hardening-brainstorm.md)
  — Key decisions carried forward: bot direct-push with bypass, lightweight dev ruleset,
  collaborators-only PRs, SHA pinning + dependabot, formula allowlist, idempotent generic
  apply script, post-update brew audit

### Internal References

- Dotfiles protect-main ruleset: `~/dotfiles/.github/rulesets/protect-main.json`
- Dotfiles protect-development ruleset: `~/dotfiles/.github/rulesets/protect-development.json`
- Existing dispatch solution:
  `docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md`
- Branch workflow enforcement:
  `~/dotfiles/docs/solutions/configuration-fixes/branch-divergence-reconciliation-and-workflow-enforcement.md`
- Git signing solution:
  `~/dotfiles/docs/solutions/deployment-issues/headless-linux-git-signing-and-hook-guards.md`

### External References

- [REST API endpoints for rules](https://docs.github.com/en/rest/repos/rules)
- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [REST API endpoints for GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions)
- [New PR Access Settings (Feb 2026)](https://github.blog/changelog/2026-02-13-new-repository-settings-for-configuring-pull-request-access/)
- [Security Hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
- [GitHub Docs: About Push Protection](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection)
- [GitHub community: Actor ID documentation for rulesets](https://github.com/github/rest-api-description/issues/4406)

### API Endpoints (from deepening research)

| Endpoint | Method | Purpose |
| -------- | ------ | ------- |
| `repos/{owner}/{repo}/rulesets` | GET/POST | List/create rulesets |
| `repos/{owner}/{repo}/rulesets/{id}` | PUT/DELETE | Update/delete ruleset |
| `repos/{owner}/{repo}/actions/permissions` | PUT | Enable Actions, set allowed_actions |
| `repos/{owner}/{repo}/actions/permissions/selected-actions` | PUT | Set action patterns (`Homebrew/*`) |
| `repos/{owner}/{repo}/actions/permissions/workflow` | PUT | Default token permissions, PR approval |
| `repos/{owner}/{repo}/actions/permissions/fork-pr-contributor-approval` | PUT | Fork PR approval policy |
| `repos/{owner}/{repo}` | PATCH | Repo settings (wiki, issues, merge methods) |
