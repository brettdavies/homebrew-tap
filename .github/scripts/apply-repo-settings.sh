#!/usr/bin/env bash
#
# apply-repo-settings.sh — Idempotent GitHub repo security hardening via gh api.
#
# Usage:
#   .github/scripts/apply-repo-settings.sh [--repo OWNER/REPO] [--dry-run]
#
# Defaults --repo to the current repo via `gh repo view`.
# Requires: gh (authenticated), jaq

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────

DRY_RUN=false
REPO=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULESETS_DIR="$(cd "$SCRIPT_DIR/../rulesets" && pwd)"

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)  REPO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--repo OWNER/REPO] [--dry-run]"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI is not installed or not in PATH." >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh is not authenticated. Run 'gh auth login' first." >&2
  exit 1
fi

if ! command -v jaq &>/dev/null; then
  echo "ERROR: jaq is not installed or not in PATH." >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

echo "=== Repository: $REPO ==="
echo "=== Dry run: $DRY_RUN ==="
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

applied=()
skipped=()
manual_steps=()

run_api() {
  local description="$1"
  shift

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] $description"
    echo "  gh api $*"
    skipped+=("$description (dry run)")
    return 0
  fi

  echo "Applying: $description"
  if gh api "$@" &>/dev/null; then
    applied+=("$description")
  else
    echo "  WARNING: Failed — $description" >&2
    skipped+=("$description (failed)")
  fi
}

# ── 1. Repo settings ─────────────────────────────────────────────────────────

echo "── Repo settings ──"

run_api "Disable wiki, projects, issues; enable squash-only merges and auto-delete branches" \
  "repos/$REPO" \
  --method PATCH \
  -f has_wiki=false \
  -f has_projects=false \
  -f has_issues=false \
  -f allow_squash_merge=true \
  -f allow_merge_commit=false \
  -f allow_rebase_merge=false \
  -f delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY

echo ""

# ── 2. Actions permissions ────────────────────────────────────────────────────

echo "── Actions permissions ──"

run_api "Restrict Actions to selected repositories/actions" \
  "repos/$REPO/actions/permissions" \
  --method PUT \
  -f enabled=true \
  -f allowed_actions=selected

run_api "Allow only actions/* and Homebrew/* action patterns" \
  "repos/$REPO/actions/permissions/selected-actions" \
  --method PUT \
  --input - <<'PATTERNS'
{
  "github_owned_allowed": false,
  "verified_allowed": false,
  "patterns_allowed": ["actions/*", "Homebrew/*"]
}
PATTERNS

run_api "Set default workflow permissions to read-only; disable Actions PR creation" \
  "repos/$REPO/actions/permissions/workflow" \
  --method PUT \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false

echo ""

# ── 3. Fork PR approval policy ───────────────────────────────────────────────

echo "── Fork PR approval policy ──"

run_api "Require approval for all outside collaborators on fork PRs" \
  "repos/$REPO/actions/permissions/fork-pr-contributor-approval" \
  --method PUT \
  -f approval_policy=all_external_contributors

echo ""

# ── 4. Rulesets ───────────────────────────────────────────────────────────────

echo "── Rulesets ──"

upsert_ruleset() {
  local json_file="$1"
  local ruleset_name
  ruleset_name="$(jaq -r '.name' "$json_file")"

  # Look up existing ruleset by name
  local existing_id
  existing_id="$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$ruleset_name\") | .id" 2>/dev/null || echo "")"

  if [[ -n "$existing_id" ]]; then
    run_api "Update ruleset: $ruleset_name (id=$existing_id)" \
      "repos/$REPO/rulesets/$existing_id" \
      --method PUT \
      --input "$json_file"
  else
    run_api "Create ruleset: $ruleset_name" \
      "repos/$REPO/rulesets" \
      --method POST \
      --input "$json_file"
  fi
}

for ruleset_file in "$RULESETS_DIR"/*.json; do
  if [[ -f "$ruleset_file" ]]; then
    upsert_ruleset "$ruleset_file"
  fi
done

echo ""

# ── 5. Collaborators-only PRs ────────────────────────────────────────────────

echo "── Collaborators-only PRs ──"

if [[ "$DRY_RUN" == true ]]; then
  echo "[DRY RUN] Attempt collaborators-only PR setting"
  skipped+=("Collaborators-only PRs (dry run)")
else
  echo "Attempting collaborators-only PR setting via API..."
  if gh api "repos/$REPO" --method PATCH -f pull_request_access_level=collaborators &>/dev/null; then
    applied+=("Collaborators-only PRs")
  else
    manual_steps+=("Set 'Who can create pull requests' to 'Collaborators' in Settings > General > Pull Requests")
    echo "  API not available — added to manual steps."
  fi
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────

echo "═══════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════"

if [[ ${#applied[@]} -gt 0 ]]; then
  echo ""
  echo "Applied (${#applied[@]}):"
  for item in "${applied[@]}"; do
    echo "  + $item"
  done
fi

if [[ ${#skipped[@]} -gt 0 ]]; then
  echo ""
  echo "Skipped (${#skipped[@]}):"
  for item in "${skipped[@]}"; do
    echo "  - $item"
  done
fi

if [[ ${#manual_steps[@]} -gt 0 ]]; then
  echo ""
  echo "Manual steps required (${#manual_steps[@]}):"
  for item in "${manual_steps[@]}"; do
    echo "  ! $item"
  done
fi

echo ""
echo "Done."
