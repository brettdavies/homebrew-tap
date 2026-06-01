#!/usr/bin/env bash
# Backports formula state from origin/main to dev so dev stays in sync
# with the bot path's main-direct PRs. Run from the dev branch after
# one or more formula bumps land on main (see chore(<formula>): bump
# to v<X.Y.Z> commits there).
#
# Usage:
#   ./scripts/sync-dev-after-release.sh                # sync every formula in Formula/
#   ./scripts/sync-dev-after-release.sh agentnative    # sync one formula
#   ./scripts/sync-dev-after-release.sh agentnative bird
#
# Idempotent. Exits 0 with no commit when dev is already in sync.
# Commits land directly on dev, establishing release backport as a
# deliberate convention. The script does NOT push; review the commit,
# then `git push origin dev` yourself.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "dev" ]; then
  printf 'error: must run on dev (currently on %s)\n' "$branch" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "error: working tree is dirty; commit or stash first" >&2
  exit 1
fi

git fetch --quiet origin main

formulas=("$@")
if [ ${#formulas[@]} -eq 0 ]; then
  formulas=()
  while IFS= read -r f; do
    formulas+=("$(basename "$f" .rb)")
  done < <(find Formula -maxdepth 1 -name '*.rb' -type f | sort)
fi

changed=()
for formula in "${formulas[@]}"; do
  path="Formula/${formula}.rb"
  if [ ! -f "$path" ]; then
    printf 'warning: %s does not exist on dev, skipping\n' "$path" >&2
    continue
  fi
  if ! git cat-file -e "origin/main:${path}" 2>/dev/null; then
    printf 'warning: %s does not exist on origin/main, skipping\n' "$path" >&2
    continue
  fi
  if git diff --quiet origin/main -- "$path"; then
    continue
  fi
  git show "origin/main:${path}" > "$path"
  git add "$path"
  changed+=("$formula")
done

if [ ${#changed[@]} -eq 0 ]; then
  echo "dev is already in sync with main on all selected formulas"
  exit 0
fi

if [ ${#changed[@]} -eq 1 ]; then
  subject="chore(${changed[0]}): sync formula from main to dev"
else
  joined=""
  for f in "${changed[@]}"; do
    joined="${joined}${f}, "
  done
  subject="chore(formulas): sync ${joined%, } from main to dev"
fi

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT
{
  printf 'Backports the following formulas from main to dev so the bot-path direct-to-main bumps do not drift away from dev:\n\n'
  printf -- '- %s\n' "${changed[@]}"
  printf '\n'
  printf 'Run after a formula bump bot PR lands on main. Documented at RELEASES.md, After a formula bump lands on main.\n'
} > "$body_file"

git commit --file="$body_file"

printf '\ncommitted: %s\n' "$subject"
echo "push with: git push origin dev"
