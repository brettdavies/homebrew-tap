# Releasing `brettdavies/homebrew-tap`

Operational runbook. Rationale lives in [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md).

The tap has two distinct release paths. Pick the one that matches the change.

```text
formula bump (bot)     repository_dispatch → update-formula.yml → PR to main → bottles via tests.yml
                       → publish.yml workflow_run → brew pr-pull → bottle block commit to main
                       → finalize-release dispatch to source repo

CI/docs/formula edits  feature branch → PR to dev (squash) → cherry-pick to release/* from main
                       → PR to main (squash)
```

Direct commits to `dev` or `main` are not permitted: every change has a PR number in its squash commit message. The two
exceptions are bot-driven commits from `update-formula.yml` and `publish.yml`, which carry the PR number in their commit
title for provenance.

## Branches

| Branch                        | Role                                             | Lifetime                                    | Protection                           |
| ----------------------------- | ------------------------------------------------ | ------------------------------------------- | ------------------------------------ |
| `main`                        | Production. Formulas + CI surface tap users see. | Forever.                                    | `.github/rulesets/protect-main.json` |
| `dev`                         | Integration. Human CI/docs PRs land here.        | Forever. Never delete.                      | `.github/rulesets/protect-dev.json`  |
| `feat/*`, `fix/*`, `docs/*`   | Feature work.                                    | One PR's worth. Auto-deleted on merge.      | None. Squash into dev freely.        |
| `release/*`                   | Head of a dev → main PR.                         | One release's worth. Auto-deleted on merge. | None.                                |
| `update/<formula>/v<version>` | Bot-created head of a formula-bump PR to main.   | One PR's worth. Deleted after bottles land. | None.                                |

→ Rationale: [`RELEASES-RATIONALE.md` § Branching model](./RELEASES-RATIONALE.md#branching-model).

## Daily development (feature → dev)

```bash
git checkout dev && git pull
git checkout -b feat/short-description
# ... work ...
git push -u origin feat/short-description
gh pr create --base dev --title "feat(scope): what changed"
# CI passes → squash-merge (PR_BODY becomes the dev commit message)
```

- **Commit style**: [Conventional Commits](https://www.conventionalcommits.org/).
- **PR body**: follow `.github/pull_request_template.md` (or the global fallback at
  `~/.config/github/pull_request_template.md`). See [§ PR body](#pr-body).
- **PR body prose scrub**: see [§ Prose scrubbing](#prose-scrubbing).

### Local pre-push hook

Once per clone, activate the repo's pre-push hook so style failures surface before the push rather than after CI runs:

```bash
git config core.hooksPath scripts/hooks
```

The hook runs `brew style` (RuboCop on `Formula/*.rb`, shfmt + shellcheck on `scripts/*.sh`) and `actionlint` on
workflow files. It mirrors `brew test-bot --only-tap-syntax`'s style phase, which is the most common CI failure on a
docs/script PR. Bypass with `git push --no-verify` only for emergency pushes; the issue still needs fixing.

Skip steps cleanly when `brew` or `actionlint` isn't on PATH — the hook never blocks pushes for missing optional
tooling.

### Dev-direct exception

Paths that live only on `dev` and never ship to `main` can be committed directly to `dev` without a feature branch or
PR. The `guard-main-docs` workflow blocks them from `main` PRs regardless. The exception applies to engineering docs:
`docs/brainstorms/`, `docs/ideation/`, `docs/plans/`, `docs/research/`, `docs/reviews/`, `docs/solutions/`, and anything
under `.context/`.

The standard feature → PR → squash-merge flow remains required for everything else, including consumer-facing markdown
(`README.md`, this file, `RELEASES-RATIONALE.md`, `RELEASES-PREFLIGHT.md`, any in-repo runbook).

## PR body

Every PR (feature, fix, docs, release, bot-generated) uses `.github/pull_request_template.md` verbatim. Six sections, no
inventions: `## Summary`, `## Changelog`, `## Type of Change`, `## Related Issues/Stories`, `## Files Modified`, `##
Testing`.

- **No explainer prose anywhere in the body.** User-facing substance only.
- **Summary describes the net diff only**: what merged `main` looks like vs the base branch. Not commit history,
  intermediate state, or cherry-pick mechanics.
- **Zero verification artifacts in the body.** No triple-diff stats, leak-check output (`guard-main-docs runs clean`,
  `no guarded paths leaked`), patch-id cherry-check counts, pre-push gate results, CI status, or prose-scrub findings.
  Anomalies get fixed before push, not audit-trailed.
- **Changelog** subsections (`### Added` / `### Changed` / `### Fixed` / `### Documentation`): 1-5 bullets each, delete
  empty subsections, each bullet starts with a verb. The tap has no `CHANGELOG.md`, so these bullets only feed release
  notes on the source-repo side via the dispatched bot updates; the field still matters for human review.
- **Type of Change**: one checkbox. Prefer `feat` / `fix` over `chore` for any user-observable change.
- **Related Issues/Stories**: four labels (`Story:` / `Issue:` / `Architecture:` / `Related PRs:`). All four required
  even when empty (`- None.` / `n/a`).
- **Files Modified**: four sub-headers (`Modified` / `Created` / `Renamed` / `Deleted`). All four required even when
  empty.
- **No AI attribution** in commits or PR bodies.
- **No hard line wraps**: one logical line per paragraph or bullet. The author hook skips `/tmp/` paths so bodies keep
  their authored shape.

→ Rationale: [`RELEASES-RATIONALE.md` § PR body conventions](./RELEASES-RATIONALE.md#pr-body-conventions).

## Formula bumps (bot path)

A source repo's `release.yml` dispatches `update-formula` to this tap. `update-formula.yml` runs the bot pipeline:

| Step               | What                                                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Validate inputs    | Formula name allowlist, version regex, repo regex. Path-traversal hardened.                                              |
| Download + SHA     | Fetch tarball from `github.com/<repo>/archive/refs/tags/v<version>.tar.gz`. Compute SHA256.                              |
| Update formula     | `sed` rewrites `url`, anchored `sha256`, strips stale `bottle do` block.                                                 |
| `brew style --fix` | Auto-corrects style nits the `sed` mutations introduce. Avoids the `Layout/InitialIndentation`-class lint failure on PR. |
| `brew audit`       | Audits the updated formula on the bot.                                                                                   |
| Open PR to main    | `update/<formula>/v<version>` head → `main`. Title `chore(<formula>): bump to v<version>`.                               |

The PR is NOT cherry-picked through dev. Bottles build on the PR via `tests.yml` (`bottles` job). When CI succeeds,
`publish.yml` (triggered by `workflow_run` on `update/**`) runs `brew pr-pull`, which downloads the bottle artifacts,
runs `brew bottle --merge --write`, commits the bottle block onto `main`, and force-pushes through
`Homebrew/actions/git-try-push`. After that, `publish.yml` dispatches `finalize-release` back to the source repo and
deletes the `update/*` branch.

The owning human's job for a bot PR is to review the formula diff and approve the merge (rulesets require human approval
to land on `main`). Everything else runs unattended.

After the bottle lands, verify the publish with [`RELEASES-POSTFLIGHT.md` § Path A](./RELEASES-POSTFLIGHT.md#path-a--formula-bump-bot-path).

### Manual fallback

If a dispatch was missed or `update-formula.yml` failed mid-run, kick it manually with:

```bash
gh workflow run update-formula.yml \
  --repo brettdavies/homebrew-tap \
  --field formula=<formula> \
  --field version=<X.Y.Z> \
  --field repo=brettdavies/<repo>
```

`workflow_dispatch` inputs mirror the dispatch `client_payload`. `repo` is the source repo's `owner/name`, not the
formula name (the two can differ — formula `agentnative` lives in `brettdavies/agentnative-cli`).

## Releasing dev to main (human path)

Engineering docs (`docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/`) live on `dev` only.
`guard-main-docs.yml` blocks them from reaching `main`, and `guard-release-branch.yml` (once installed) rejects any PR
to main whose head isn't `release/*`. The convention is followed manually today; landing the workflow makes it a hard
gate.

**Branch naming**: `release/<slug>` (e.g. `release/ci-brew-tap-trust`, `release/lint-hardening-option-d`,
`release/owner-repo-derivation`). No version prefix — the tap has no versioned releases. The slug should describe what
is being promoted from dev to main.

```bash
# 1. Branch from main, NOT dev. (Avoids add/add conflicts on guarded paths.)
git fetch origin
git checkout -b release/<slug> origin/main

# 2. List the dev commits not yet on main.
git log --oneline dev --not origin/main

# 3. Cherry-pick the ones to ship. Docs commits stay on dev.
git cherry-pick <sha1> <sha2> ...

# 4. Triple-diff verification.
git diff origin/main..HEAD --stat                                              # A: ship surface
git diff HEAD..origin/dev --name-only | grep -v '^docs/' || echo "(none)"      # B: no missed picks
git diff origin/dev..origin/main --stat | tail -5                              # C: phantom-commits sanity

# Re-confirm no guarded paths leaked.
git diff origin/main..HEAD --name-only \
  | grep -E '^(docs/plans|docs/brainstorms|docs/ideation|docs/reviews|docs/solutions|\.context)' \
  && echo "LEAKED — reset and redo" || echo "(clean)"

# Patch-id cherry check (noisy in squash-merge workflow; triage per-line).
git cherry HEAD origin/dev | grep '^+' || echo "(none)"

# 5. Push and open the PR. Scrub body in /tmp/ first.
git push -u origin release/<slug>
gh pr create --base main --head release/<slug> --title "release: <one-line>" --body-file /tmp/body.md
```

When the PR merges, the change is live on `main`. Auto-delete removes `release/<slug>` from the remote. `dev` is
untouched by this merge. A separate back-merge of formula files is required after bot formula bumps; see
[§ After a formula bump lands on main](#after-a-formula-bump-lands-on-main). Verify the promotion with
[`RELEASES-POSTFLIGHT.md` § Path B](./RELEASES-POSTFLIGHT.md#path-b--cidocs-release-release--main).

→ Rationale + triple-diff false-positive triage:
[`RELEASES-RATIONALE.md` § Triple-diff verification](./RELEASES-RATIONALE.md#triple-diff-verification).

### Cherry-pick conflicts on guarded paths

Cherry-picks of feature PRs that touched `docs/plans/` / `docs/brainstorms/` / `docs/ideation/` / `docs/reviews/` /
`docs/solutions/` / `.context/` files will hit modify/delete conflicts on the release branch. Those paths exist on `dev`
but are blocked from `main` by `guard-main-docs.yml`, so the cherry-pick sees them as "deleted in HEAD, modified in
`<commit>`". A PR that renames such a file produces rename/delete conflicts on the same paths.

Resolution (the standard `git rm` is denied by repo policy; use the plumbing form):

```bash
# 1. Mark every unmerged guarded path as deleted in the index.
git update-index --remove $(git diff --name-only --diff-filter=U)

# 2. Trash the orphan worktree files left by the rename target side.
#    `trash` is a zsh alias to `gio trash`; xargs does not expand aliases,
#    so call `gio trash` directly when piping or batching.
gio trash docs/plans/<leftover-paths>.md

# 3. Continue the cherry-pick.
git cherry-pick --continue --no-edit
```

Repeat per conflicting commit. After all picks land, run `git ls-files docs/plans/ docs/brainstorms/`. If anything
remains, drop it with the same two-step pattern and commit as `chore(release): drop stray plan spikes from cherry-pick
rename detection` before step 4's leak check.

### After a formula bump lands on main

Formula bumps land directly on `main` via the bot path (`update-formula.yml` PR → squash, then `publish.yml`'s `brew
pr-pull` writing the bottle block). Neither commit touches `dev`, so `dev`'s copy of each formula goes stale the moment
the bot ships a new version. The drift is silent: dev still builds, lints, and cherry-picks fine — but the next
`release/<slug>` cut from `main` will appear to "regress" each formula if a release-branch cherry-pick from `dev` also
touches `Formula/`.

The remedy is a backport from `main` to `dev` after each formula bump bot PR lands on main:

```bash
./scripts/sync-dev-after-release.sh                  # sync all formulas
# or, for a single formula:
./scripts/sync-dev-after-release.sh <formula>
```

The script branches off `origin/dev`, copies each drifted formula verbatim from `origin/main`, and opens a PR against
`dev` — the PR-only convention applies, so the backport carries a PR number like every other change. It is idempotent:
if `dev` already matches `main` on the selected formulas, it exits 0 without creating a branch or PR. Review and
squash-merge the PR once CI is green.

→ Rationale:
[`RELEASES-RATIONALE.md` § Why dev needs a back-merge for formula files](./RELEASES-RATIONALE.md#why-dev-needs-a-back-merge-for-formula-files).

## Prose scrubbing

Two release-flow artifacts live outside any automated prose check and need a manual scrub before they ship:

- PR bodies (`gh pr create` / `gh pr edit` send body text directly to GitHub).
- Release-PR bodies (composed after cherry-picks are verified).

Bot-generated formula-bump PR bodies do NOT need a scrub — they ship one literal line of body text.

```bash
# 1. Save the artifact to /tmp/.
gh pr view <num> --json body --jq .body > /tmp/body.md

# 2. Vale (point at any nearby spec checkout that ships rule packs).
vale --no-global --output=line --minAlertLevel=error /tmp/body.md

# 3. LanguageTool grammar check via lt_check (~/dotfiles/config/shell/languagetool.sh).
#    Skips cleanly if LT is unreachable. Inspect: `lt_rules`, `lt_info`.
lt_check /tmp/body.md

# 4. unslop (em-dash density and AI-unique structural patterns).
~/.claude/skills/unslop/scripts/score.py /tmp/body.md

# 5. Apply fixes per finding. Re-run until 0 blocking and unslop score is 0.

# 6. Apply the cleaned version.
gh pr edit <num> --body-file /tmp/body.md
```

→ Rationale + which artifacts need this:
[`RELEASES-RATIONALE.md` § Prose scrubbing scope](./RELEASES-RATIONALE.md#prose-scrubbing-scope).

## Branch protection

Two rulesets are committed under `.github/rulesets/` and applied to the repo via the GitHub API:

- `protect-main.json`: linear history, squash-only merges via PR, required status checks (`lint`, `guard-docs /
  check-forbidden-docs`, `guard-provenance / check-provenance`), creation/deletion blocked, non-fast-forward blocked.
  Bypass is configured for the admin role so the owner's PAT can land bot PRs and CI housekeeping commits (e.g. bottle
  block writes from `publish.yml`).
- `protect-dev.json`: deletion blocked, non-fast-forward blocked. PR-only norm is convention plus
  `guard-release-branch.yml` (once installed) on the `main` side.

### Applying changes

```bash
# First apply (creating a ruleset):
gh api -X POST repos/brettdavies/homebrew-tap/rulesets --input .github/rulesets/protect-dev.json

# Subsequent updates (replace by ID — find via `gh api repos/brettdavies/homebrew-tap/rulesets`):
gh api -X PUT repos/brettdavies/homebrew-tap/rulesets/<id> --input .github/rulesets/protect-main.json
```

→ Status-check context strings (inline vs reusable):
[`RELEASES-RATIONALE.md` § Status-check context strings](./RELEASES-RATIONALE.md#status-check-context-strings).

## Required secrets

| Secret             | Purpose                                                                                                                                             | Lifecycle         |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `CI_RELEASE_TOKEN` | Fine-grained PAT, Contents R+W, Pull requests R+W. Used by `update-formula.yml` to open PRs, `publish.yml` to `brew pr-pull` and dispatch upstream. | Rotated annually. |

`GITHUB_TOKEN` is automatic and sufficient for `tests.yml`, `guard-main-docs.yml`, `guard-main-provenance.yml`, and
`guard-release-branch.yml`.

## Related docs

- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md) (release-flow rationale, branching model, branch-protection
  pitfalls)
- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) (pre-release verification checklist for dev → main promotions)
- [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md) (post-ship verification for the bot formula-bump path and dev →
  main releases)
- [`README.md`](./README.md) (install instructions for tap users)
- `~/.config/github/pull_request_template.md` (PR body structure with changelog sections; the tap has no in-repo
  template)
