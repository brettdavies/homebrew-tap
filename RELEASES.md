# Releasing `brettdavies/homebrew-tap`

Operational runbook. Rationale lives in [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md).

The tap has two distinct release paths. Pick the one that matches the change.

```text
formula bump (bot)     repository_dispatch → update-formula.yml → PR to main → bottles via tests.yml
                       → publish.yml workflow_run → brew pr-pull → bottle block commit to main
                       → finalize-release dispatch to source repo

CI/docs/formula edits  feature branch → PR to dev (squash) → release/* cut from main, dev's tree overlaid
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

### Local pre-commit and pre-push hooks

Once per clone, activate both hooks with the same setting:

```bash
git config core.hooksPath scripts/hooks
```

**Pre-commit** (fast, staged-file-only, runs on every commit): `brew style` on staged `Formula/*.rb` and `*.sh`
outside `scripts/release/`, `shfmt -i 2 -ci -bn -d` plus `shellcheck --severity=warning` on staged
`scripts/release/*.sh`, `shellcheck --severity=warning` on staged extensionless files under `scripts/hooks/`, and
`actionlint` on staged `.github/workflows/*.yml`. Each check is a no-op with a notice when its tool isn't installed, so
a missing linter never blocks a commit.

**Pre-push** runs `brew style` (RuboCop on `Formula/*.rb`, shfmt + shellcheck on the tap-authored `scripts/*.sh`),
`brew readall`, `brew audit`, `shellcheck` on the hooks, `actionlint` on workflow files, and `shfmt` + `shellcheck
--severity=warning` on the vendored `scripts/release/*.sh`. It mirrors the `lint` job in `tests.yml`, which is the most
common CI failure on a docs/script PR. Bypass with `git push --no-verify` only for emergency pushes; the issue still
needs fixing.

Pre-push requires `brew`, `actionlint`, `shellcheck`, and `shfmt` and fails (not skips) if any is missing, so the lint
can never be silently bypassed. Pre-commit skips cleanly instead, favoring fast local iteration over a hard gate.

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

After the bottle lands, verify the publish with
[`RELEASES-POSTFLIGHT.md` § Path A](./RELEASES-POSTFLIGHT.md#path-a-formula-bump-bot-path).

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
formula name (the two can differ: formula `agentnative` lives in `brettdavies/agentnative-cli`).

## Releasing dev to main (human path)

Before cutting a release branch, walk [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) end-to-end. Any unchecked item
holds the release.

Engineering docs (`docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/`) live on `dev` only.
`guard-main-docs.yml` blocks them from reaching `main`. The tap does not run `guard-release-branch.yml`, because the
bot path opens PRs to `main` from `update/<formula>/v<version>` heads; the `release/*` naming below is a convention
enforced by review (see [§ Project specifics](#project-specifics)).

**Branch naming**: `release/<slug>` (e.g. `release/ci-brew-tap-trust`, `release/lint-hardening-option-d`,
`release/owner-repo-derivation`). No version prefix; the tap has no versioned releases. The slug should describe what
is being promoted from dev to main.

`main` and `dev` share only an ancient merge-base: every release squash-merges into `main`, and the bot path lands
formula commits on `main` that never touch `dev`, so the two branches diverge in history even as their content
converges. Reconciling that with a merge, or a branch cut from `dev`, produces add/add and rename/delete conflicts that
are artifacts of the lineage, not of the content shipping. The release branch is therefore built as a **clean
descendant of `main`** with `dev`'s tree overlaid on top, asserting the desired end-state directly:

```bash
# 0. Nothing on main that dev never received (formula bumps and bottle blocks from the bot
#    path, hotfixes, config). Exits 1 while drift exists. The tap has no tags and its release
#    squashes read `release: <slug>`, so pass the last release squash on main as the anchor;
#    without it the gate lists every commit since the merge base.
scripts/release/drift.sh --since <sha of the last "release:" squash on main>

# 1. Branch from main, NOT dev.
git fetch origin
git checkout -B release/<slug> origin/main

# 2. Overlay dev's entire tracked tree onto the main base. `checkout -- .` writes dev's
#    paths but does not delete files that exist on main and are absent on dev, so remove
#    those next (the 'D' rows are main-only files dev deleted).
git checkout origin/dev -- .
git diff --name-status origin/main origin/dev | grep '^D'
trash <each main-only file listed above>

# 3. Strip the paths guard-main-docs forbids on main. The set resolves from the workflow;
#    never restate it inline, because every hand-kept copy drifted from what CI enforces.
GUARDED="$(scripts/release/guarded-paths.sh)"
git ls-files | grep -E "$GUARDED" | xargs -r trash
git add -A                                                      # stages adds, mods, AND deletions

# 4. No version bump and no changelog: the tap has no version carrier and no CHANGELOG.md
#    (see § Project specifics).

# 5. Verify before committing.
#    A: staged tree equals dev's minus the stripped guarded paths. Anything else printed
#       here is a mistake.
git diff --cached --name-only origin/dev | grep -Ev "$GUARDED" \
  && echo "unexpected delta above; investigate" || echo "(clean: only intended deltas)"
#    B: no guarded path in the release tree.
git diff --cached --name-only origin/main | grep -E "$GUARDED" \
  && echo "LEAKED a guarded path: reset and redo" || echo "(no guarded paths)"
#    D: what this release ADDS to main. The leak check screens against the registered
#       set, so it is blind to a category nobody registered yet. Every docs/ entry and
#       every added markdown file needs a reason to ship, or it needs registering in the
#       workflow's extra_paths and removing from the branch.
git diff --cached --diff-filter=A --name-only origin/main | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED" || echo "(none unguarded)"

# 6. Commit the overlay as one commit sitting directly on top of main, then re-run the
#    drift gate so a formula bump that landed on main during the cut is caught before
#    the PR opens (re-cut from the new main if it reports one).
git commit
scripts/release/drift.sh --since <sha>

# 7. Push and open the PR. Scrub body in /tmp/ first.
git push -u origin release/<slug>
gh pr create --base main --head release/<slug> --title "release: <one-line>" --body-file /tmp/body.md
```

The result is a single commit whose diff against `main` is the release, with `main` as an ancestor, so the PR merges
with zero conflicts. When it merges, the change is live on `main`. Auto-delete removes `release/<slug>` from the
remote. `dev` is untouched by this merge. Verify the promotion with
[`RELEASES-POSTFLIGHT.md` § Path B](./RELEASES-POSTFLIGHT.md#path-b-cidocs-release-release--main).

→ Rationale (why overlay, not merge; why cut from `main`):
[`RELEASES-RATIONALE.md` § Branching model](./RELEASES-RATIONALE.md#branching-model).

### Exception: cherry-pick

The overlay is the release construction. Cherry-picking the dev squash-commits onto the `origin/main` base is the
exception, kept for a promotion that must leave part of `dev` behind (a workflow change that is not ready to ship while
a formula edit is). When cherry-picking, run the triple-diff verification:

```bash
# 2. List the dev commits not yet on main.
git log --oneline dev --not origin/main

# 3. Cherry-pick the ones to ship. Docs commits stay on dev.
git cherry-pick <sha1> <sha2> ...

# 4. Triple-diff verification.
GUARDED="$(scripts/release/guarded-paths.sh)"

git diff origin/main..HEAD --stat                                              # A: ship surface
git diff HEAD..origin/dev --name-only | grep -Ev "$GUARDED" || echo "(none)"   # B: no missed picks
git diff origin/dev..origin/main --stat | tail -5                              # C: phantom-commits sanity

# Re-confirm no guarded paths leaked.
git diff origin/main..HEAD --name-only \
  | grep -E "$GUARDED" \
  && echo "LEAKED: reset and redo" || echo "(clean)"

# D: what this release ADDS to main (see step 5 above for why).
git diff origin/main..HEAD --diff-filter=A --name-only | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED" || echo "(none unguarded)"

# Patch-id cherry check (noisy in squash-merge workflow; triage per-line).
git cherry HEAD origin/dev | grep '^+' || echo "(none)"
```

Cherry-picks of PRs that touched guarded paths hit modify/delete or rename/delete conflicts, since those paths live on
`dev` but are blocked from `main`; resolve them per the next section. Steps 6 and 7 of the overlay recipe then apply
unchanged.

→ Triple-diff false-positive triage:
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
the bot ships a new version. The drift is silent: dev still builds and lints fine, but the next `release/<slug>`
overlay of `dev`'s tree onto `main` would write the stale formula back over the shipped one. `scripts/release/drift.sh`
lists the gap and holds the cut until this backport has merged.

The remedy is a backport from `main` to `dev` after each formula bump bot PR lands on main:

```bash
./scripts/sync-dev-after-release.sh                  # sync all formulas
# or, for a single formula:
./scripts/sync-dev-after-release.sh <formula>
```

The script branches off `origin/dev`, copies each drifted formula verbatim from `origin/main`, and opens a PR against
`dev`; the PR-only convention applies, so the backport carries a PR number like every other change. It is idempotent:
if `dev` already matches `main` on the selected formulas, it exits 0 without creating a branch or PR. Review and
squash-merge the PR once CI is green. Never merge `main` into `dev` or push to `dev` directly: the squash-merged
histories share no recent ancestry, so the merge conflicts on every file both sides touched, and a direct push bypasses
`dev`'s required checks.

→ Rationale:
[`RELEASES-RATIONALE.md` § Why dev needs a back-merge for formula files](./RELEASES-RATIONALE.md#why-dev-needs-a-back-merge-for-formula-files).

## Rollback

A bad formula is rolled back at the surface users consume, the formula file on `main`, and then fixed upstream.
Rollback re-points what `brew install` resolves; it does not rewrite history. The last-good identifier is the bottle
commit of the previous version on `main` (the `<formula>: add <version> bottle.` row in `git log origin/main --oneline
-- Formula/<formula>.rb`); recording it before a bump lands is a [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md)
gate.

```bash
git fetch origin
git checkout -B release/rollback-<formula>-<version> origin/main
git checkout <last-good-bottle-commit> -- "Formula/<formula>.rb"
git commit
git push -u origin release/rollback-<formula>-<version>
gh pr create --base main --head release/rollback-<formula>-<version> \
  --title "fix(<formula>): roll back to v<last-good>" --body-file /tmp/body.md
```

The rollback is a `main`-first change, like a bot bump: backport it to `dev` afterwards with
`./scripts/sync-dev-after-release.sh <formula>`. `brew upgrade` never downgrades an installed newer version, so users
who already have the bad one run `brew reinstall brettdavies/tap/<formula>`. The source repo's release stays as it is;
the fixed version arrives as a new bump through the bot path and supersedes the rollback.

→ Rationale: [`RELEASES-RATIONALE.md` § Rollback](./RELEASES-RATIONALE.md#rollback).

## Prose scrubbing

Two release-flow artifacts live outside any automated prose check and need a manual scrub before they ship:

- PR bodies (`gh pr create` / `gh pr edit` send body text directly to GitHub).
- Release-PR bodies (composed after the overlay is verified).

Bot-generated formula-bump PR bodies do NOT need a scrub; they ship one literal line of body text.

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
- `protect-dev.json`: deletion blocked, non-fast-forward blocked. PR-only norm is convention on the `main` side; see
  [§ Project specifics](#project-specifics) for why `guard-release-branch.yml` is not installed.

### Applying changes

```bash
# First apply (creating a ruleset):
gh api -X POST repos/brettdavies/homebrew-tap/rulesets --input .github/rulesets/protect-dev.json

# Subsequent updates (replace by ID; find it via `gh api repos/brettdavies/homebrew-tap/rulesets`):
gh api -X PUT repos/brettdavies/homebrew-tap/rulesets/<id> --input .github/rulesets/protect-main.json
```

→ Status-check context strings (inline vs reusable):
[`RELEASES-RATIONALE.md` § Status-check context strings](./RELEASES-RATIONALE.md#status-check-context-strings).

## Project specifics

### No guard-release-branch

`guard-release-branch.yml` rejects any PR to `main` whose head is not `release/*`. The tap's bot path opens
`update/<formula>/v<version>` PRs to `main` from `update-formula.yml`, and `publish.yml` pushes the bottle-block commit
to `main` directly, so the guard would block every formula bump. The tap does not install it; the `release/<slug>` head
convention for human promotions is enforced by review, and `guard-main-provenance.yml` still requires a PR reference on
every human commit.

### No version carrier, no changelog

The tap has no `Cargo.toml`, `package.json`, `pyproject.toml`, or `VERSION`, and no `CHANGELOG.md`, so the release
recipe carries no version-bump step and the repo vendors neither `scripts/generate-changelog.py` nor `cliff.toml`.
Formula versions live in each formula's `url` and `bottle do` block and move only through the bot path.

### Vendored release scripts

`scripts/release/` holds `_lib.sh`, `drift.sh`, and `guarded-paths.sh`, copied verbatim from the `github-repo-setup`
skill; there is no preflight or postflight orchestrator because the tap has no tag pipeline. The tree follows that
skill's `shfmt -i 2 -ci -bn` and `shellcheck --severity=warning` profile, which `brew style` would rewrite, so the
`lint` job in `tests.yml` and both hooks keep it out of `brew style` and check it with those two tools instead. Refresh
it by copying from the skill again; never edit it in place.

`scripts/sync-dev-after-release.sh` is the tap's own script, not the skill's: it backports `Formula/*.rb` from `main`
to `dev` by PR, because formula state is the only thing that lands on `main` first here.

### Required secrets

| Secret             | Purpose                                                                                                                                             | Lifecycle         |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `CI_RELEASE_TOKEN` | Fine-grained PAT, Contents R+W, Pull requests R+W. Used by `update-formula.yml` to open PRs, `publish.yml` to `brew pr-pull` and dispatch upstream. | Rotated annually. |

`GITHUB_TOKEN` is automatic and sufficient for `tests.yml`, `guard-main-docs.yml`, and `guard-main-provenance.yml`.

## Related docs

- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md) (release-flow rationale, branching model, branch-protection
  pitfalls)
- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) (pre-release verification checklist for dev → main promotions)
- [`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md) (post-ship verification for the bot formula-bump path and dev →
  main releases)
- [`README.md`](./README.md) (install instructions for tap users)
- `~/.config/github/pull_request_template.md` (PR body structure with changelog sections; the tap has no in-repo
  template)
