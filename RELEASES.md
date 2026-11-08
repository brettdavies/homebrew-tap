<!-- canonical: version-scheme none -->
# Releasing `brettdavies/homebrew-tap`

Operational runbook. Rationale lives in [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md).

The tap has two distinct release paths. Pick the one that matches the change.

```text
formula bump (bot)     repository_dispatch → update-formula.yml
                           bump    check the inputs, verify the release's archives, pin the checksums
                           lint    brew style, readall, audit, bats on the bumped formula
                           test    install and test on four platforms
                           land    the bump commit on main → finalize-release dispatch to the source repo

CI/docs/formula edits  feature branch → PR to dev (squash) → release/* cut from main, dev's tree overlaid
                       → PR to main (squash)
```

Direct commits to `dev` or `main` are not permitted: every change has a PR number in its squash commit message. The
exception is the bot path. `update-formula.yml` pushes a formula bump to `main` as one commit with no pull request, and
its message names the source release and the run that tested it.

## Branches

| Branch                      | Role                                             | Lifetime                                    | Protection                           |
| --------------------------- | ------------------------------------------------ | ------------------------------------------- | ------------------------------------ |
| `main`                      | Production. Formulas + CI surface tap users see. | Forever.                                    | `.github/rulesets/protect-main.json` |
| `dev`                       | Integration. Human CI/docs PRs land here.        | Forever. Never delete.                      | `.github/rulesets/protect-dev.json`  |
| `feat/*`, `fix/*`, `docs/*` | Feature work.                                    | One PR's worth. Auto-deleted on merge.      | None. Squash into dev freely.        |
| `release/*`                 | Head of a dev → main PR.                         | One release's worth. Auto-deleted on merge. | None.                                |

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

**Pre-commit** (fast, staged-file-only, runs on every commit): `brew style` on staged `Formula/*.rb` and on staged
`*.sh` outside the vendored scripts, `shfmt -i 2 -ci -bn -d` plus `shellcheck --severity=warning` on the staged
vendored scripts (`scripts/release/*.sh` and `scripts/check-workflow-concurrency.sh`), `shellcheck --severity=warning`
on staged extensionless files under `scripts/hooks/`, and `actionlint` plus `scripts/check-workflow-concurrency.sh` when
a `.github/workflows/*.yml` is staged. Each check is a no-op with a notice when its tool isn't installed, so a missing
linter never blocks a commit.

**Pre-push** runs `brew style` (RuboCop on `Formula/*.rb`, shfmt + shellcheck on the tap-authored `scripts/*.sh`),
`brew readall`, `brew audit`, `shellcheck` on the hooks, `actionlint` and `scripts/check-workflow-concurrency.sh` on
workflow files, `shfmt` + `shellcheck --severity=warning` on the vendored scripts, and the `bats` tests under `tests/`.
It mirrors the `lint` job in `tests.yml`, which is the most common CI failure on a docs/script PR. Bypass with
`git push --no-verify` only for emergency pushes; the issue still needs fixing.

Pre-push requires `brew`, `actionlint`, `shellcheck`, `shfmt`, `bats`, and `node` and fails (not skips) if any is
missing, so the lint can never be silently bypassed. The exceptions are a push that only deletes remote refs
(`git push origin --delete <branch>`) and a push with no ref to update: neither delivers a commit, so pre-push exits 0
before it looks for any tool.
Pre-commit skips cleanly instead, favoring fast local iteration over a hard gate.

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
- **Changelog** subsections (`### Breaking changes` / `### Added` / `### Changed` / `### Deprecated` / `### Fixed` /
  `### Documentation`): 1-5 bullets each, delete empty subsections, each bullet starts with a verb. The tap has no
  `CHANGELOG.md`, so these bullets only feed release notes on the source-repo side via the dispatched bot updates; the
  field still matters for human review.
- **Type of Change**: one checkbox. Prefer `feat` / `fix` over `chore` for any user-observable change.
- **Related Issues/Stories**: four labels (`Story:` / `Issue:` / `Architecture:` / `Related PRs:`). All four required
  even when empty (`- None.` / `n/a`).
- **Files Modified**: four sub-headers (`Modified` / `Created` / `Renamed` / `Deleted`). All four required even when
  empty.
- **No AI attribution** in commits or PR bodies.
- **No hard line wraps**: one logical line per paragraph or bullet. The author hook skips `/tmp/` paths so bodies keep
  their authored shape.

→ Rationale: [`RELEASES-RATIONALE.md` § PR body conventions](./RELEASES-RATIONALE.md#pr-body-conventions).

## Versioning

<!-- canonical:begin versioning-none -->

This repo ships no version and cuts no release tag.

<!-- canonical:repo-begin how-it-ships -->

Every merge to `main` is live: a formula bump the bot path lands, or a `release:` squash that promotes `dev`.

<!-- canonical:repo-end -->

<!-- canonical:end versioning-none -->

## Formula bumps (bot path)

A source repo's `release.yml` dispatches `update-formula` to this tap with the formula, the version, and the source
repo. `update-formula.yml` lands the bump on `main` in one run, with no pull request:

| Job    | What                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bump` | Checks the formula name against the allowlist, the version and repo against their patterns, and the repo against the one the formula's `url` names, and refuses a source-built formula. Downloads each archive the formula names from the `v<version>` release, verifies them side by side with `gh attestation verify --signer-workflow`, then pins each one's SHA256 under its `url` and reads the pair back. Strips any `bottle do` block and uploads the bumped formula. It sets up no Homebrew: `lint` and every leg audit the file. |
| `lint` | `brew style`, `brew readall`, the tap's `brew audit`, and the bats suite, on the bumped formula, as `tests.yml`'s `lint` job runs them. A formula the `sed` left unstyled fails here.                                                                                                                                                                                                                                                                                                                                                     |
| `test` | On ubuntu-24.04, ubuntu-24.04-arm, macos-15, and macos-26, with `fail-fast: false`: `brew fetch`, `brew install --build-from-source` (which installs the archive and compiles nothing), `brew audit --online --git`, `brew linkage --test`, and `brew test`.                                                                                                                                                                                                                                                                              |
| `land` | Runs only when `bump`, `lint`, and all four legs passed. Reads `main`'s copy of the formula and stops when it changed after the run's commit. Commits the bump as `chore(<formula>): bump to v<version>`, pushes it to `main` through `Homebrew/actions/git-try-push` in the `publish-formula` concurrency group, so two bumps never push at once, reads `main` again, and dispatches `finalize-release` back to the source repo once `main` holds the file every check ran on.                                                           |

An archive that does not verify, a failed lint, or a failed leg stops the run before `land`, so `main` is unchanged.
`main` gains one commit per bump, and the formula carries no bottle block. When `main` already holds the bumped file,
`land` commits and pushes nothing and still dispatches `finalize-release`, so a rerun after a dispatch that failed
completes the release.

Every formula in the tap installs its release's prebuilt archives, and the tap builds and publishes no bottles. A
source-built formula, one that builds its tagged tarball, is refused: `update-formula.yml` stops its bump as
`source-built-formula`, and `tests.yml` refuses it on a pull request. `scripts/formula-form.sh` says which form a
formula has, for both workflows.

After the bump lands, verify the publish with
[`RELEASES-POSTFLIGHT.md` § Path A](./RELEASES-POSTFLIGHT.md#path-a-formula-bump-bot-path).

### When a bump stops

Each stop `update-formula.yml` names is an error annotation titled with its code, and its link opens the heading below
as it stands at the run's own commit. The annotation names the values that caused it, says whether `main` moved, and
gives the command that recovers; a command that still holds a `<placeholder>` is one to finish first.
`tests/update-formula.bats` fails when a coded annotation has no heading here.

| Where                       | Code                                                 | `main`                       | Next                                                                                                                                                     |
| --------------------------- | ---------------------------------------------------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bump`, input checks        | `invalid-input`, `repo-mismatch`, `push-from-branch` | unchanged                    | Dispatch again with the field the annotation names.                                                                                                      |
| `bump`, form check          | `source-built-formula`                               | unchanged                    | Convert the formula, then dispatch again.                                                                                                                |
| `bump`, download            | `release-download-failed`                            | unchanged                    | Rerun once the release carries its archives.                                                                                                             |
| `bump`, attestation check   | `archive-not-attested`                               | unchanged                    | Depends on the cause; see its heading.                                                                                                                   |
| `bump`, checksum rewrite    | `checksum-not-pinned`                                | unchanged                    | Fix the formula's layout, then dispatch again.                                                                                                           |
| `lint`                      | none: `brew`'s own output                            | unchanged                    | A style or audit failure is the formula's: fix it on `main` through the human path, then dispatch again.                                                 |
| a `test` leg                | none: `brew`'s own output                            | unchanged                    | A download or network error passes on `gh run rerun <id> --failed`. A failure that repeats, or that every leg shares, is the formula's or the release's. |
| `land`, checkout            | `release-token-rejected`                             | unchanged                    | A person rotates `CI_RELEASE_TOKEN`.                                                                                                                     |
| `land`, before the commit   | `formula-moved`                                      | unchanged                    | Bump again from `main`; the annotation gives the command.                                                                                                |
| `land`, push                | `push-failed`                                        | unchanged                    | Depends on the cause; see its heading.                                                                                                                   |
| `land`, before the dispatch | `formula-moved`                                      | holds an edit no job checked | Bump again from `main`; the annotation gives the command.                                                                                                |
| `land`, dispatch            | `finalize-dispatch-failed`                           | has the bump                 | Rerun `land`, which pushes nothing new.                                                                                                                  |

#### `invalid-input`

The dispatch named a formula outside the allowlist (`xurl-rs`, `bird`, `agentnative`), a version that is not `X.Y.Z`
without a `v`, a repo that is not `brettdavies/<name>`, or a formula with no file in the tap. Dispatch again with the
field fixed; the annotation fills the version in when the input only adds a `v`.

#### `repo-mismatch`

The formula's `url` lines name one repo, and the dispatch named another. `land` sends `finalize-release` to the
dispatched repo, so a mismatch would finalize the wrong release, or none. Dispatch again with the repo the annotation
names; [§ Manual fallback](#manual-fallback) lists each formula's repo. When the source repo was renamed, the formula's
`url` lines move to the new name through the human path first.

#### `source-built-formula`

The formula builds its tagged source tarball, and `update-formula.yml` lands only a formula that installs the prebuilt
archives its release publishes. Convert the formula to the prebuilt form (the `homebrew-tap-publish` skill's prebuilt
template), land that through the human path, then run the bump again with the command in
[§ Manual fallback](#manual-fallback).

#### `push-from-branch`

A run without `dry_run` ran from a branch other than `main`. Its checkout is that branch, and `git-try-push` pushes
local `main`, which it creates from `origin/main`. The push would carry nothing, the run would pass, and
`finalize-release` would mark the source release latest with the formula unchanged. Land the bump from `main`, or
rehearse on the branch with `dry_run=true`; the annotation gives both commands.

#### `release-download-failed`

`gh release download` could not fetch the archives the formula names from the `v<version>` release: the release does
not exist, carries no asset under that name, or GitHub's API failed. `gh release view v<version> --repo <repo>` shows
the release and its assets. Once it has them, `gh run rerun <id> --failed` runs `bump` again.

#### `archive-not-attested`

One or more archives did not verify against an attestation signed by `rust-release.yml`, and each one's
`gh attestation verify` output is in its own log group. Output that finds no attestation means the source repo's
`release.yml` calls `rust-release.yml` without `attest: true`: turn it on, publish a release whose archives carry the
attestation, then dispatch again. An error from the attestation API clears on `gh run rerun <id> --failed`. An
attestation that names other bytes means the archive was replaced after it was signed: escalate, and bump nothing.

#### `checksum-not-pinned`

The rewrite sets each archive's checksum on the line under its `url`, and the read-back found that line is not the
archive's `sha256`. The formula's layout is the cause: put each `url` line directly above its `sha256` line through the
human path, then dispatch again.

#### `release-token-rejected`

`land`'s checkout with `CI_RELEASE_TOKEN` failed, so the token is expired, revoked, or no longer reads this repository.
Nothing was pushed. A person rotates the secret ([§ Required secrets](#required-secrets) names its scopes), then
`gh run rerun <id> --failed` runs `land` again.

#### `formula-moved`

`Formula/<formula>.rb` on `main` changed after the run's commit, so the file `lint` and the test legs checked is not the
one a push would land: `git-try-push`'s rebase would merge the other edit into it, or drop the bump as already applied.
`land` reads `main` before it commits and stops with nothing pushed or dispatched. It reads `main` again before the
dispatch, for an edit that landed while the push rebased; that stop leaves `main` holding a file no job checked, and
dispatches nothing. Either way, a fresh run from `main` bumps and tests what `main` holds:
`gh workflow run update-formula.yml --ref main -f formula=<formula> -f version=<version> -f repo=<repo>`. A
`gh run rerun --failed` stops the same way, since a rerun keeps the run's commit.

#### `push-failed`

`git-try-push` did not push the bump within its retries, and its output says why. `main` did not move, and the source
release is not finalized. A 403 means a person rotates `CI_RELEASE_TOKEN`, and a ruleset refusal means the token's
bypass on the `main` ruleset is gone; for anything else, `gh run rerun <id> --failed` runs `land` again.

#### `finalize-dispatch-failed`

The one stop after `main` has the bump: the push landed, or `main` already pinned the version, and the
`finalize-release` dispatch to the source repo failed. The source release is published and not yet marked latest. A 403
or 404 means `CI_RELEASE_TOKEN` cannot reach the source repo, which a person grants. Otherwise `gh run rerun <id>
--failed` runs `land` again: its push finds the bump already on `main` and pushes nothing, and it sends the dispatch.

### Manual fallback

If a dispatch was missed or `update-formula.yml` failed mid-run, kick it manually with:

```bash
gh workflow run update-formula.yml \
  --repo brettdavies/homebrew-tap \
  --field formula=<formula> \
  --field version=<X.Y.Z> \
  --field repo=brettdavies/<repo>
```

`workflow_dispatch` inputs mirror the dispatch `client_payload`. `repo` is the source repo's `owner/name`, which the
formula's `url` lines name and which can differ from the formula's name:

| Formula       | `repo`                        |
| ------------- | ----------------------------- |
| `xurl-rs`     | `brettdavies/xurl-rs`         |
| `bird`        | `brettdavies/bird`            |
| `agentnative` | `brettdavies/agentnative-cli` |

A failed run can also be rerun with `gh run rerun <id> --failed`. Runs are titled `Update <formula> to v<version>`,
with `(dry run)` after a rehearsal's title, and a rehearsal's `land` adds a `dry-run` notice naming the commit it would
have pushed.

`dry_run=true` rehearses the run: every job runs, and `land` composes the commit but skips the push to `main` and the
`finalize-release` dispatch. A run that pushes is accepted only from `main`; a rehearsal can run from any branch with
`--ref <branch>`.

```bash
gh workflow run update-formula.yml \
  --repo brettdavies/homebrew-tap \
  --ref <branch> \
  --field formula=<formula> \
  --field version=<X.Y.Z> \
  --field repo=brettdavies/<repo> \
  --field dry_run=true
```

## Releasing dev to main (human path)

Before cutting a release branch, walk [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) end-to-end. Any unchecked item
holds the release.

Engineering docs (`docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/`) live on `dev` only.
`guard-main-docs.yml` blocks them from reaching `main`. The tap does not run `guard-release-branch.yml`; the
`release/*` naming below is a convention enforced by review (see [§ Project specifics](#project-specifics)).

**Branch naming**: `release/<slug>` (e.g. `release/ci-brew-tap-trust`, `release/lint-hardening-option-d`,
`release/owner-repo-derivation`). No version prefix; the tap has no versioned releases. The slug should describe what
is being promoted from dev to main.

`main` and `dev` share only an ancient merge-base: every release squash-merges into `main`, and the bot path lands
formula commits on `main` that never touch `dev`, so the two branches diverge in history even as their content
converges. Reconciling that with a merge, or a branch cut from `dev`, produces add/add and rename/delete conflicts that
are artifacts of the lineage, not of the content shipping. The release branch is therefore built as a **clean
descendant of `main`** with `dev`'s tree overlaid on top, asserting the desired end-state directly:

```bash
# 0. Nothing on main that dev never received (formula bumps from the bot path, hotfixes,
#    config). Exits 1 while drift exists. The tap has no tags, so the gate
#    anchors on the newest `release:` squash on main. Gate 0 (the anchor's bookkeeping on
#    dev) passes here on every run: the tap has no version carrier or CHANGELOG.md.
scripts/release/drift.sh

# 1. Branch from main, NOT dev.
git fetch origin
git checkout -B release/<slug> origin/main

# 2. Overlay dev's entire tracked tree onto the main base. `checkout -- .` writes dev's
#    paths but does not delete files that exist on main and are absent on dev, so remove
#    those next (the 'D' rows are main-only files dev deleted or moved). `--no-renames`
#    lists a moved file as a deletion; rename detection would report it as an R row,
#    and the stale copy left behind would ship to main.
git checkout origin/dev -- .
git diff --no-renames --name-status origin/main origin/dev | grep '^D'
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
#       `--no-renames` lists a doc moved from one main carries as added; rename detection
#       would report it as R, and the A filter would drop it.
git diff --cached --no-renames --diff-filter=A --name-only origin/main | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED" || echo "(none unguarded)"

# 6. Commit the overlay as one commit sitting directly on top of main, then re-run the
#    drift gate so a formula bump that landed on main during the cut is caught before
#    the PR opens (re-cut from the new main if it reports one).
git commit
scripts/release/drift.sh

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
# `--no-renames` lists a doc moved from one main carries as added; rename detection
# would report it as R, and the A filter would drop it.
git diff --no-renames origin/main..HEAD --diff-filter=A --name-only | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED" || echo "(none unguarded)"

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

Repeat per conflicting commit. After all picks land, run `git ls-files | grep -E "$(scripts/release/guarded-paths.sh)"`.
If anything remains, drop it with the same two-step pattern and commit as `chore(release): drop stray plan spikes from
cherry-pick rename detection` before step 4's leak check.

### After a formula bump lands on main

Formula bumps land directly on `main` via the bot path (`update-formula.yml` pushes the bump commit). It never touches
`dev`, so `dev`'s copy of each formula goes stale the moment the
bot ships a new version. The drift is silent: dev still builds and lints fine, but the next `release/<slug>` overlay of
`dev`'s tree onto `main` would write the stale formula back over the shipped one. `scripts/release/drift.sh` lists the
gap and holds the cut until this backport has merged.

The remedy is a backport from `main` to `dev` after each formula bump lands on main:

```bash
./scripts/sync-formulas-to-dev.sh                  # sync all formulas
# or, for a single formula:
./scripts/sync-formulas-to-dev.sh <formula>
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

A bad formula is rolled back at the surface users consume, the formula file on `main`, and then fixed upstream. Rollback
re-points what `brew install` resolves; it does not rewrite history. The last-good identifier is the last commit the
previous version's bump put on `main`, read from `git log origin/main --oneline -- Formula/<formula>.rb`: the
`chore(<formula>): bump to v<version>` row. Recording it before a bump lands is a
[`RELEASES-POSTFLIGHT.md`](./RELEASES-POSTFLIGHT.md) gate.

```bash
git fetch origin
git checkout -B release/rollback-<formula>-<version> origin/main
git checkout <last-good-commit> -- "Formula/<formula>.rb"
git commit
git push -u origin release/rollback-<formula>-<version>
gh pr create --base main --head release/rollback-<formula>-<version> \
  --title "fix(<formula>): roll back to v<last-good>" --body-file /tmp/body.md
```

The rollback is a `main`-first change, like a bot bump: backport it to `dev` afterwards with
`./scripts/sync-formulas-to-dev.sh <formula>`. `brew upgrade` never downgrades an installed newer version, so users
who already have the bad one run `brew reinstall brettdavies/tap/<formula>`. The source repo's release stays as it is;
the fixed version arrives as a new bump through the bot path and supersedes the rollback.

→ Rationale: [`RELEASES-RATIONALE.md` § Rollback](./RELEASES-RATIONALE.md#rollback).

## Prose scrubbing

Two release-flow artifacts live outside any automated prose check and need a manual scrub before they ship:

- PR bodies (`gh pr create` / `gh pr edit` send body text directly to GitHub).
- Release-PR bodies (composed after the overlay is verified).

Bot bump commits do NOT need a scrub; they carry fixed text and open no PR.

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

- `protect-main.json`: creation, deletion, and non-fast-forward pushes blocked; required status checks, strict (the head
  must be current with `main`), for `guard-docs / check-forbidden-docs` and `guard-provenance / check-provenance` (no
  `guard-release` context; see [§ No guard-release-branch](#no-guard-release-branch)). Bypass is configured for the
  admin role so the owner's PAT can push the bump `update-formula.yml` lands.
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

`guard-release-branch.yml` rejects any PR to `main` whose head is not `release/*`. A formula bump is pushed to `main`
with no PR. The tap does not install the guard; the `release/<slug>` head convention
for human promotions is enforced by review, and `guard-main-provenance.yml` still requires a PR reference on every human
commit.

### No version carrier, no changelog

The tap has no `Cargo.toml`, `package.json`, `pyproject.toml`, or `VERSION`, and no `CHANGELOG.md`, so the release
recipe carries no version-bump step and the repo vendors neither `scripts/generate-changelog.py` nor `cliff.toml`.
Formula versions live in each formula's `url` lines and move only through the bot path.

### Vendored release scripts

`scripts/release/` holds `_lib.sh`, `drift.sh`, and `guarded-paths.sh`, copied verbatim from the `github-repo-setup`
skill, as is `scripts/check-workflow-concurrency.sh`; there is no preflight or postflight orchestrator because the tap
has no tag pipeline. These scripts follow that skill's `shfmt -i 2 -ci -bn` and `shellcheck --severity=warning`
profile, which `brew style` would rewrite, so the `lint` job in `tests.yml` and both hooks keep them out of
`brew style` and check them with those two tools instead. Refresh them by copying from the skill again; never edit them
in place.

`scripts/sync-formulas-to-dev.sh` is the tap's own script: it backports `Formula/*.rb` from `main` to `dev` by PR,
because formula state is the only thing that lands on `main` first here. The tap does not vendor the skill's
`scripts/sync-dev-after-release.sh`, which backports a release's version and changelog bookkeeping: the tap has neither.
Drift gate 0 names that script in its failure hint, and gate 0 passes on every run here.

### Required secrets

| Secret             | Purpose                                                                                                                 | Lifecycle         |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `CI_RELEASE_TOKEN` | Fine-grained PAT, Contents R+W, Pull requests R+W. Used by `update-formula.yml` to push the bump and dispatch upstream. | Rotated annually. |

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
