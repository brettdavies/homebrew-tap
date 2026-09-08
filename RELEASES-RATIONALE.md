# Releases rationale

Companion to [`RELEASES.md`](./RELEASES.md). RELEASES.md is the runbook (commands, paths, decision tables). This file
holds the WHY behind those rules: branching model, PR conventions, release pipeline, prose-check pipeline,
branch-protection pitfalls, tap-specific quirks.

Read this when:

- A rule in RELEASES.md doesn't make sense and you're tempted to change it.
- A new contributor asks "why do we do X this way".
- You're adding a new release-flow rule and need to know where it fits the existing model.

## Branching model

### Forever `dev`, ephemeral release branches

`dev` is never deleted, even after a promotion to main. The next promotion cycle reuses the same `dev`. The repo's
`deleteBranchOnMerge: true` setting doesn't touch `dev` as long as `dev` is never the head of a PR. Using a short-lived
`release/*` head is what keeps the setting compatible with a forever integration branch.

Engineering docs (`docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, `docs/reviews/`) live on `dev` only. They never
reach `main`. `guard-main-docs.yml` blocks them from PRs targeting `main`. The tap does not run
`guard-release-branch.yml`: the bot path opens `update/<formula>/v<version>` PRs to `main`, which the guard would
reject; see [`RELEASES.md` § Project specifics](./RELEASES.md#project-specifics).

### Why the release branch is cut from `main`, never from `dev`

Every release squash-merges into `main`, and the bot path lands formula commits on `main` that never touch `dev`, so
`dev` and `main` diverge in history even as their content converges: after the first release they share only an
ancient merge-base. Cutting the release branch from `dev` (or merging `dev` into `main`) forces a 3-way merge across
that divergence: `add/add` collisions on files both sides changed, plus rename/delete pairs git cannot auto-resolve.
The conflict pile is an artifact of the lineage, not of the content shipping.

Always cut the release branch from `origin/main` and bring `dev`'s content onto it as a forward diff, never by
reconciling histories. The default is the whole-tree overlay (`git checkout origin/dev -- .`, then strip the guarded
set): `main` ships `dev`'s tree minus a small, known exclusion set, so asserting that end-state directly is simpler and
safer than hand-resolving a merge. The tap has no changelog to rebuild from per-PR history, so the overlay commit
carrying none costs nothing. Cherry-picking the dev squash-commits is kept only as an exception for a promotion that
must leave part of `dev` behind, at the cost of guarded-path conflict handling.

Either way, the release must start from a `main` that `dev` fully contains. Formula bumps and bottle blocks land on
`main` first, and both constructions take `dev`'s content for the files they touch, so anything `main` holds that `dev`
never received is reverted by the release. `scripts/release/drift.sh` lists that set and the cut waits until it is
empty; for formulas, `scripts/sync-dev-after-release.sh` is what empties it.

### Why no version prefix on release branches

The tap is not a versioned artifact. There is no `Cargo.toml`, no `package.json`, no tag pipeline that consumes the
branch name. A promotion to main is "the change went live for tap users", not "v0.2.0 shipped". Branch slugs describe
what's being promoted (`release/ci-brew-tap-trust`, `release/owner-repo-derivation`) rather than encoding a version.

The tap formulas themselves are versioned, but their bumps run on a separate path: `update-formula.yml` opens
`update/<formula>/v<version>` heads directly against `main`, and the version lives in the formula's `url` and
(post-pr-pull) `bottle do` block, not in any tap-level identifier.

### Why formula bumps bypass dev

The bot path (`update-formula.yml`) opens its PRs to `main`, not `dev`. Three reasons:

1. **Repository dispatches read the workflow file from the default branch**, which is `main`. Routing the bot PR through
   `dev` first would mean the workflow on `main` opens a PR to `dev`, then a human cuts a `release/*` branch, then a
   human promotes to main. Three round-trips for what is mechanically a one-line `sed`-and-audit run. The
   latency between an upstream tag and bottles available to users would be measured in days.
2. **The bottle pipeline keys off the `update/<formula>/v<version>` head pattern.** `tests.yml`'s `bottles` job triggers
   on this pattern via the `detect` job; `publish.yml` filters its `workflow_run` trigger on `branches: ["update/**"]`.
   Inserting a dev hop would either break the trigger or require the bot to re-create the same head pattern after a dev
   squash, which loses provenance.
3. **The change set is narrow and machine-generated.** The bot writes to exactly one file (`Formula/<formula>.rb`), runs
   `brew audit` on the bot, and the tests.yml CI runs full bottle builds on the PR. Human review is the formula diff;
   nothing about that review benefits from a dev integration window.

The provenance guard (`guard-main-provenance.yml`) still applies: bot PRs squash with `(#N)` titles (`chore(<formula>):
bump to v<version> (#66)`), so the squash commit on main has a PR reference. The publish.yml `brew pr-pull` step writes
a follow-up commit (`<formula>: add <version> bottle.`) without a PR number, which is expected: that commit comes from
the publish bot, not from a PR, and the guard treats bot-routed commits as authoritative.

## PR body conventions

### No explainer prose in the body

Every section of a PR body is user-facing substance only: the **net diff**, what is changing for the consumer that was
not already there, not the commit history or intermediate state that produced it. Workflow mechanics (cherry-pick,
pre-push gate, CI behavior) is documented in RELEASES.md and `.github/`, NOT in the PR body. Triple-diff output ("A: 12
files, B: none, C: clean"), leak-check narration (`guard-main-docs runs clean`, `no guarded paths leaked`), patch-id
cherry-check counts, pre-push gate results, CI check status, exclusion rationale, and other verification artifacts stay
local; anomalies get fixed before push, not audit-trailed in the body.

The PR body is read by humans reviewing what shipped. Workflow mechanics and tool-fix provenance are noise from that
perspective; they belong in this file, the script outputs, and the commit history respectively.

### Why `feat`/`fix` are preferred over `chore`

Even though the tap has no in-repo `CHANGELOG.md`, the PR title becomes the squash-commit subject and the dispatched
update notification text on the source-repo side. Conventional Commit types that read as user-observable (`feat` /
`fix`) communicate intent to anyone scanning the tap's commit history. `chore` mistyping for a user-observable change
buries the change. Prefer `feat` / `fix` when the change has any user-observable effect (formula default behavior, CI
output that ships to PR comments, install instructions).

### Why required-when-empty sub-headers

`Related Issues/Stories` has four labels (`Story:` / `Issue:` / `Architecture:` / `Related PRs:`). `Files Modified` has
four sub-headers (`Modified` / `Created` / `Renamed` / `Deleted`). All four must appear in every PR, even when empty:
write `- None.` or `n/a` rather than deleting the label. Reason: scanners and humans both rely on a known section shape.
Conditionally-absent sections force every reader to mentally check "did the author skip this or does it not apply?"

### Why no AI attribution

`Co-Authored-By: Claude …`, `🤖 Generated with [Claude Code]`, or any similar AI-attribution trailer is banned from
commit messages and PR bodies. Commits and PRs stand on their own technical content. Attribution trailers are noise and
they age poorly as tools shift.

### Why no hard line wraps

Author each paragraph and each bullet as one logical line, however long. GitHub soft-wraps for display. Hard wraps
within prose produce visible mid-sentence breaks in some renderers and interfere with the prose-check pipeline: Vale's
line-anchored output reports findings against split lines, LanguageTool's input handling can choke on certain
control-char interactions. The auto-format hook skips `/tmp/` paths so the body keeps its authored shape; don't undo
that with manual wrapping during composition. Same rule applies to commit messages composed via heredoc or `--file`.

## Triple-diff verification

The release-PR procedure runs three diffs (A: main→release, B: release→dev filtered by the guarded set, C: dev→main)
plus, on the cherry-pick exception, a patch-id cherry check. This is belt-and-suspenders because missed cherry-picks
have shipped to `main` on sibling repos before, and the file-level diff in B alone doesn't catch the patch-id
false-negative class.

### Why the guarded set resolves from the workflow

`guard-main-docs` is what CI enforces on a PR to `main`: the reusable workflow's hardcoded base list plus this repo's
`extra_paths`. Every hand-kept copy of that union (runbook, checklist, postflight) drifted from it, and a copy that
omits a guarded path reports a real leak as clean while CI turns red after the push.
`scripts/release/guarded-paths.sh` reads `extra_paths` out of the caller workflow and adds the base list, so
registering a path in the workflow is the only edit a new guarded path needs. The base list is the one copy that still
needs a manual edit when the reusable changes, because it lives in another repo. Entries are globs with one rule set
shared by the reusable and the script (`**/` any depth, `*` and `?` within a segment, trailing slash guards the
subtree), so the two never disagree about what is guarded.

### Why the release enumerates what it adds

The leak check screens the diff against the registered set, so it says nothing about a category nobody registered. A
new engineering directory or a stray note under `docs/` passes the local check and `guard-main-docs` alike. Step D
lists every `docs/` file and every markdown file the release adds to `main` outside the guarded set and puts them in
front of a human; each one needs a reason to ship, or it gets registered in `extra_paths` and dropped from the branch.
Root-level markdown is in scope because a note at the repo root is exactly the kind of addition a `docs/`-only listing
misses.

### Why patch-id cherry-check output is noisy

In a squash-merge workflow, `git cherry HEAD origin/dev` produces many `+` lines that need human triage. They do NOT
auto-block the release. Expected sources of false positives:

1. **Historical commits squash-merged in prior promotions.** The squash commit on main has a different patch-id than the
   dev commits it consolidates, so old commits show as `+` forever. Anything older than the previous release-style
   promotion is almost always this.
2. **Cherry-picks where conflict resolution stripped guarded paths** (`docs/plans/`, `docs/brainstorms/`, etc.) or
   otherwise altered the tree. Same source-code intent, different patch-id.
3. **Intentionally skipped commits** (docs-only commits, formula bumps that landed via the bot path and never went
   through dev).

A real miss looks like: a recent feat/fix/docs commit on dev whose *file content* is not yet on main. To triage a `+`
line:

```bash
git show <sha> --stat                       # what did it touch?
git diff origin/main..HEAD -- <those-files> # already on release?
```

If every touched file is guarded (`docs/plans/`, `docs/brainstorms/`, etc.) OR the content is already on main via a
prior squash or a bot-path commit, it's a false positive (no action). Otherwise cherry-pick the commit and re-run the
triple-diff.

## Release pipeline

### The two paths, again

The tap has no tag-triggered release pipeline. There are two trigger surfaces instead:

- **Bot path**: a source repo's `release.yml` POSTs to `repos/brettdavies/homebrew-tap/dispatches` with
  `event_type=update-formula` and a `client_payload` containing `formula`, `version`, `repo`. `update-formula.yml` picks
  it up, opens an `update/<formula>/v<version>` PR to main. `tests.yml`'s `bottles` job builds the bottle on
  ubuntu-24.04, macos-14, macos-15. After the PR squash-merges, `publish.yml` (workflow_run, branches `update/**`) runs
  `brew pr-pull` to commit the bottle block onto main and dispatches `finalize-release` back to the source repo.
- **Human path**: feat/fix/docs branch → PR to dev (squash) → `release/<slug>` branch cut from main with `dev`'s tree
  overlaid → PR to main (squash). No tag, no auto-publish; the merge to main IS the release.

The two paths share `main` as their landing target. Neither sees the other before merge.

### Why `update-formula.yml` runs `brew style --fix` between `sed` and `brew audit`

The `sed` mutations that rewrite `url` and `sha256` can introduce style nits (e.g. `Layout/InitialIndentation`) that
`brew audit --strict` rejects. Running `brew style --fix --formula <formula>` between the mutations and the audit
auto-corrects those nits in place so the PR ships already passing the `lint` job's style and audit phases. Without
this step, every bot PR needed a manual style-cleanup commit before bottles could build, the pattern that motivated
landing the auto-fix as #61. → See
[solutions: github-ruleset-merge-state-blocked-bypass-actors](https://github.com/brettdavies/solutions-docs/blob/main/workflow-issues/github-ruleset-merge-state-blocked-bypass-actors-20260318.md)
for the bypass-actor behavior that makes the bot PR mergeable despite a `BLOCKED` ruleset state.

### Why `publish.yml` uses `brew pr-pull` (not `brew pr-upload`)

`brew pr-pull` is the only path that runs `brew bottle --merge --write` and commits the assembled bottle block onto the
target branch. `brew pr-upload --no-upload` (the obvious-looking alternative) skips the merge-write step entirely and
publishes nothing.

`--root-url` on `brew pr-pull` overrides the tap-repo default destination for downloaded bottle artifacts, pointing at
the source repo's release assets path. `HOMEBREW_GITHUB_API_TOKEN` must be `CI_RELEASE_TOKEN` (not the default
`GITHUB_TOKEN`) because the token needs write to the source repo to attach bottles to its release.

### Why bot PR provenance commits don't trip `guard-main-provenance`

The `(#N)` rule expects every commit on main to carry a PR reference. Bot-path commits split into two:

- `chore(<formula>): bump to v<version> (#66)`: the squash of the `update/<formula>/v<version>` PR. Has `(#N)`.
- `<formula>: add <version> bottle.`: the follow-up commit from `publish.yml`'s `brew pr-pull` writing the bottle
  block. No PR reference.

The provenance guard treats `<formula>: add <version> bottle.` as a recognized bot-bottle commit pattern and lets it
through. Manually authored commits without a PR reference still fail the guard.

### Why no `CHANGELOG.md` in the tap

A tap is a directory of formulas, not a versioned package. There is no semantic version to anchor a release entry
against. Release notes for each formula live on the source repo's GitHub Release page (and in the source repo's own
`CHANGELOG.md`); the tap's role is distribution, not announcement.

### Why dev needs a back-merge for formula files

The bot path lands two commits directly on `main` per formula bump: the squash of `update/<formula>/v<version>` (e.g.
`chore(<formula>): bump to v<X.Y.Z> (#N)`) and the `publish.yml` follow-up (`<formula>: add <version> bottle.`). Neither
commit reaches `dev`, so `dev`'s copy of `Formula/<formula>.rb` falls behind by one version every bot bump. After a few
bumps, the gap is invisible during daily dev work (formulas lint and audit fine in isolation) but lethal at release
time: cutting `release/<slug>` from `main` and cherry-picking a dev commit that happens to touch the same formula path
(directly or via rename-detection drift) reverts main's formula state to dev's older snapshot.

`scripts/sync-dev-after-release.sh` resolves this by overwriting dev's `Formula/<name>.rb` with `origin/main`'s content
for each formula on a `chore/sync-dev-*` branch cut from `origin/dev`, then opening a PR against `dev`. The backport is
that PR, never a merge of `main` into `dev` and never a direct push: the squash-merged histories share no recent
ancestry, so a merge conflicts on every file both sides touched, and a direct push to `dev` bypasses its required
checks. `tests.yml` recognizes the `chore/sync-dev*` head and skips bottle builds for it, since the formula text was
already built, bottled, and published from `main`. Source repos have an analogous script for `Cargo.toml` +
`Cargo.lock` + `CHANGELOG.md`; the tap's version is narrower because the only file that drifts is the formula, which is
why the tap keeps its own script rather than the skill's.

The script overwrites whole files, not specific lines. This is safe because a human-authored formula edit on dev (e.g.
adding a `depends_on`) follows the standard feat/* branch + PR flow and lands on `dev`'s tip via a normal squash; the
sync script's intended invocation is on a clean `dev` HEAD that has already received any human-authored changes. If the
working tree is dirty the script refuses to run.

`scripts/release/drift.sh` is the check that the backport happened: its first gate lists every `main` commit whose
changes `dev` does not contain, and an un-backported formula shows up there until the sync PR merges.

### Rollback

Rollback happens at the surface users consume, which for a tap is the formula file on `main`, not in git history.
Restoring the last-good formula revision through a `release/rollback-*` PR is fast and reversible; rewriting `main` is
neither, and the release flow exists so that `main` only ever moves forward through a PR. After the rollback, the fix
arrives as a new bump through the bot path (or, for a workflow regression, through `dev` and a fresh `release/<slug>`),
so the branch reconverges with what is live. Recording the last-good identifier before a bump or promotion lands is
what makes the rollback a single command under incident pressure.

## Prose scrubbing scope

Two release-flow artifacts live outside any automated prose check and need a manual scrub before they ship:

- **PR bodies.** `gh pr create` and `gh pr edit` send body text directly to GitHub; no automated prose check has reach
  there.
- **Release-PR bodies.** The `release/<slug>` PR to `main` carries contributor-authored wrap-up text composed after the
  cherry-picks are verified, and the same out-of-repo gap applies.

Bot-generated PR bodies (`Automated formula update for <formula> v<version>.`) are not scrubbed; they're a single fixed
sentence with no prose surface.

Scrub-before-submit (author in `/tmp/`, scrub there, submit via `--body-file`) avoids the round-trip of "submit, scrub,
edit, scrub again". Every fix lands locally and the public PR sees only clean text. The auto-format hook skips `/tmp/`
paths so the body keeps its authored shape and no soft-wrapping is injected.

## Branch protection

### Status-check context strings

The `required_status_checks[].context` strings in `protect-main.json` MUST match exactly what GitHub publishes for each
check:

- **Inline job** (with `name:` field): published as just `<job-name>` (no workflow-name prefix). `lint` from `tests.yml`
  is the canonical example.
- **Reusable-workflow caller** (`uses: .../foo.yml@ref`): published as `<caller-job-id> / <reusable-job-id-or-name>`.
  `guard-docs / check-forbidden-docs` and `guard-provenance / check-provenance` are the examples.

Mixing these produces a stuck-but-green PR: all actual checks report green, but the ruleset waits forever on a context
that will never appear. Confirm the real contexts after a first CI run with:

```bash
gh api repos/brettdavies/homebrew-tap/commits/<sha>/check-runs --jq '.check_runs[].name'
```

### Why bypass actors can still merge despite a `BLOCKED` state

GitHub's `mergeStateStatus` evaluates from the non-bypass perspective: when a ruleset includes an `update` rule that the
head branch hasn't satisfied, the API reports `BLOCKED` even though the configured bypass actor (admin-role PAT) can
still complete the merge. The owner's PAT is the configured bypass; tooling that gates merge on `BLOCKED == false` will
refuse correctly-mergeable PRs. → See
[solutions: github-ruleset-merge-state-blocked-bypass-actors](https://github.com/brettdavies/solutions-docs/blob/main/workflow-issues/github-ruleset-merge-state-blocked-bypass-actors-20260318.md).

### Why rulesets live in-repo

Committing the JSON alongside code means ruleset changes land via the same review process as workflow changes. A
`chore(ci): tighten protect-main` change goes through dev → release/* → main like anything else.

### Why personal-repo bypass uses RepositoryRole, not Integration

`Integration` actor type (`actor_type: "Integration"`) is org-only. Personal repos can only express bypass via the admin
RepositoryRole (`actor_id: 5, actor_type: "RepositoryRole"`), which covers the owner's PAT. Copying an org ruleset
verbatim onto a personal repo silently fails the JSON validation on the bypass clause.

## Related docs

- [`RELEASES.md`](./RELEASES.md) (operational runbook: commands, paths, decision tables)
- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md) (pre-release verification checklist for dev → main promotions)
- [`README.md`](./README.md) (install instructions for tap users)
- `~/.config/github/pull_request_template.md` (PR body structure with changelog sections)
