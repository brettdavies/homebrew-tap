# Brainstorm: Repository Security Hardening

**Date:** 2026-03-16
**Status:** Draft
**Repo:** brettdavies/homebrew-tap

## What We're Building

A comprehensive security hardening of the homebrew-tap repository to ensure only the owner (or owner's PATs) can modify the repo. The configuration will be source-controlled in `.github/` (matching the dotfiles pattern) and applied via `gh api` where possible, with manual steps documented for UI-only settings.

## Why This Approach

**Approach A: Layered Source-Controlled Configs** was chosen over Terraform IaC (overkill for one repo) and pure documentation (not source-controlled). This mirrors the existing dotfiles pattern where rulesets live as JSON in `.github/rulesets/` and can be applied programmatically.

## Threat Model

This is a **public** repository (required for Homebrew taps). Key threats:

- **Malicious PRs from strangers** — Formula files are Ruby code executed during `brew install`
- **Supply chain attacks via formula tampering** — Compromised formula = arbitrary code execution on user machines
- **Workflow exploitation** — Fork PR workflows, expression injection, compromised Actions
- **Unauthorized pushes** — Direct pushes bypassing review/CI

## Current State (Gaps)

| Setting | Current | Desired |
|---------|---------|---------|
| Rulesets | None | Protect `main` + `dev` |
| PR access | Anyone can open PRs | Collaborators only |
| Merge methods | All three enabled | Squash only |
| Auto-delete branches | Off | On |
| Wiki | Enabled | Disabled |
| Projects | Enabled | Disabled |
| Issues | Enabled | Disabled |
| Actions permissions | All allowed | Restricted to `actions/*`, `Homebrew/*` |
| Default workflow perms | Not read-only | Read-only |
| Fork PR workflows | Default (first-time approval) | Require approval for all |
| Actions can create PRs | Unknown | Disabled |
| Action SHA pinning | Partial (update-formula yes, tests no) | All pinned |
| Dependabot (Actions) | None | Weekly updates |
| CODEOWNERS | None | `* @brettdavies` |
| Secret scanning | Default (likely on) | Verified on, delegated bypass |
| Commit signing | Not enforced | Required via rulesets |

## Key Decisions

### 1. Bot pushes directly to main (no PR)

`update-formula.yml` will continue pushing directly to `main`. The `protect-main` ruleset grants `github-actions[bot]` bypass for the PR requirement. This preserves the "fully automated" workflow.

### 2. Dev ruleset stays lightweight

`protect-dev` requires signed commits only — no PR requirement. The owner pushes directly to `dev` during development. PRs are only required for `dev` -> `main`.

### 3. Issues disabled

Formula problems are upstream tool bugs. Users should file issues on the tool repos (xurl-rs, bird). Reduces noise and moderation burden.

### 4. Pin all Actions to SHA + dependabot

All third-party Actions (except `Homebrew/actions/setup-homebrew@main` per Homebrew's recommendation) will be pinned to full-length commit SHA. A `dependabot.yml` for the `github-actions` ecosystem will propose updates weekly.

### 5. Restrict Actions to allowlisted orgs

Only `actions/*` and `Homebrew/*` are permitted. This prevents compromised workflows from introducing malicious third-party actions.

### 6. Collaborators-only PRs

Use GitHub's Feb 2026 "Collaborators only" PR setting to block fork PRs at creation time. Only the owner and PATs can open PRs. The apply script will attempt to set this via API; if the endpoint doesn't exist, document as a manual UI step.

### 7. Apply script is idempotent and generic

The script checks for existing rulesets by name and updates in place (or creates if missing). Safe to re-run anytime. Accepts a `--repo` flag (defaults to current repo via `gh`) so it can be reused across brettdavies repos.

### 8. Formula allowlist in update-formula.yml

Validate the formula name against a hardcoded allowlist (`xurl-rs`, `bird`). Prevents a compromised token from creating arbitrary formula files. Must be updated when adding new tools.

### 9. Post-update brew audit

Add a `brew audit --formula <name>` step to `update-formula.yml` after the sed replacement and before the commit. Catches malformed Ruby before it lands on main.

## Implementation Plan (Files)

### Source-controlled configs

| File | Purpose |
|------|---------|
| `.github/rulesets/protect-main.json` | Main branch ruleset (PR + squash + signatures + status checks) |
| `.github/rulesets/protect-dev.json` | Dev branch ruleset (signatures only) |
| `.github/dependabot.yml` | GitHub Actions version updates |
| `.github/CODEOWNERS` | Ownership declaration |
| `.github/scripts/apply-repo-settings.sh` | Applies repo settings, Actions perms, rulesets via `gh api` |

### Ruleset: protect-main.json

Adapted from dotfiles `protect-main.json` with additions:

- Restrict creations (prevent creating `main` branches)
- Restrict updates (prevent direct pushes)
- Restrict deletions
- Block force pushes
- Require pull request (0 approvals, squash only)
- Require signed commits
- Require status checks (`brew test-bot`)
- Require linear history
- Bypass: Admin role (for owner), `github-actions[bot]` (for formula updates)

### Ruleset: protect-dev.json

- Restrict deletions
- Block force pushes
- Require signed commits
- Bypass: Admin role

### apply-repo-settings.sh

Applies via `gh api`:

1. **Repo settings** — disable wiki, projects, issues; enable squash-only; enable auto-delete branches
2. **Actions permissions** — restrict to `actions/*`, `Homebrew/*`; set default token to read-only; disable "create and approve PRs"
3. **Fork PR workflows** — require approval for all outside collaborators
4. **Rulesets** — create/update from JSON files
5. **PR access** — set to collaborators only (if API-supported; document if UI-only)

### Workflow hardening (in tests.yml)

- Pin `actions/cache` and `actions/upload-artifact` to SHA
- Add formula allowlist to `update-formula.yml` input validation

## What Can't Be Done

| Desire | Reality |
|--------|---------|
| Prevent forking | Not possible on public repos |
| Prevent viewing code | Not possible on public repos (required for taps) |
| Require PR reviews as solo dev | Impractical (can't approve own PRs); use CI as merge gate |
| Fully prevent fork PR workflows | Mitigated by collaborators-only PRs + require approval for all |

## Resolved Questions

- **Bot push model?** Direct push to main with ruleset bypass (not PR-based)
- **Dev branch protection level?** Lightweight (signed commits only)
- **Issues?** Disabled — direct users to upstream tool repos
- **Actions pinning?** Pin all to SHA + dependabot for updates
- **Implementation approach?** Source-controlled configs in `.github/` + apply script
- **Script idempotency?** Idempotent — check/update existing rulesets, safe to re-run
- **Script reusability?** Generic with `--repo` flag, defaults to current repo
- **Formula allowlist?** Yes — hardcoded list (`xurl-rs`, `bird`), update when adding tools
- **Post-update validation?** Yes — `brew audit --formula` before committing
- **Collaborators-only PR setting?** Try API first, fall back to documented manual step

## Open Questions

None — all key decisions resolved.
