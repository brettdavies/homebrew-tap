# Pre-release verification: `brettdavies/homebrew-tap`

Operational pre-flight checklist. Runs **before** step 1 of
[`RELEASES.md` § Releasing dev to main](./RELEASES.md#releasing-dev-to-main-human-path). Gates the cut of the
`release/<slug>` branch, not the daily dev integration. Each box is an explicit go/no-go. If any item is unchecked or
red, hold the release.

The automated part is `scripts/release/drift.sh`; there is no preflight orchestrator because the tap has no tag
pipeline, so every other item below is a manual `git`, `gh`, `brew`, or `curl` check.

This checklist applies only to the **human path** (dev → main promotions). The **bot path** (`update-formula.yml` → PR
to main → `publish.yml`) runs unattended and has its own in-workflow gates (formula audit on the bot, full bottle CI on
the PR, `brew pr-pull` only on green CI). Reviewing a bot PR is the diff plus a click; no preflight required.

CI on dev (lint job in `tests.yml`) catches mechanical regressions inside the tap repo. This checklist covers what CI
structurally can't:

- Bottle URLs the formulas point at, after `dev` has moved (the URL is set when the bot opened the bump PR; CI doesn't
  re-verify it on every dev push).
- Cross-workflow trigger integrity (does `publish.yml` still match `tests.yml`'s output filenames; does
  `update-formula.yml` still dispatch with the right `client_payload` shape).
- Token health (`CI_RELEASE_TOKEN` expiration is silent until a real dispatch fails).
- Distribution paths that only exercise on real downloads (`brew install brettdavies/tap/<formula>` from a clean cache).

## Establish the surface

Everything below assumes you know what's changing. Run this first.

```bash
git fetch origin
git log origin/main..origin/dev --oneline                                  # commits going out
git diff origin/main..origin/dev --stat                                    # file-level scope
git diff origin/main..origin/dev -- Formula/                               # formula-shape surface
git log origin/main..origin/dev --grep '^[a-z]\+\(([^)]*)\)\?!:' --oneline # breaking markers, scoped or not
```

The tap has no tags, so the surface is `origin/main..origin/dev` rather than a `$LAST_TAG..dev` range. Every `!:`
commit drives a `### Breaking changes` section in the release PR body and probably warrants a tap-user heads-up in the
README.

## Checklist

### Branch drift (main ahead of dev)

Driven by `scripts/release/drift.sh --since <sha of the last "release:" squash on main>`. The tap has no tags and its
release squashes read `release: <slug>`, so without `--since` the gate anchors on the merge base and lists every commit
since.

Formula bumps and bottle blocks land on `main` first through the bot path, and hotfixes or config edits can too. The
release branch is cut from `main` and then takes `dev`'s tree, so anything `main` holds that `dev` never received is
reverted by the release.

- [ ] Every commit on `main` since the anchor has its changes on `dev` (gate 1 lists the ones that do not, as `differs`
      or `missing`). A formula row means a bot bump is un-backported: run `./scripts/sync-dev-after-release.sh
      <formula>`, merge the PR, and rerun. Any other row is a `main`-first change to backport by PR into `dev` first.
- [ ] `.github/` is identical on both branches (gate 2). Dependabot bumps on `dev` are the routine direction and ship
      with this release; a workflow edit that only reached `main` is drift.
- [ ] Gate 3 (lockfiles) SKIPs: the tap carries none.

### Tap-surface scope

- [ ] Diff under `Formula/`: every changed line is intentional. The `sed`-mutated formulas (bot path) should NOT appear
  here; those land via the bot's PR-to-main path, not via dev. A formula change on dev means a human edited it.
- [ ] Dev is in sync with main on every `Formula/<name>.rb` file. Run `git diff origin/main..origin/dev -- Formula/`
  before cutting `release/<slug>`; the output should be empty. If it isn't, run `./scripts/sync-dev-after-release.sh`
  and merge its PR before continuing (drift gate 1 reports the same gap). → See
  [`RELEASES-RATIONALE.md` § Why dev needs a back-merge for formula files](./RELEASES-RATIONALE.md#why-dev-needs-a-back-merge-for-formula-files).
- [ ] Diff under `.github/workflows/`: every changed workflow has been actionlint-clean since its last edit. The
  pre-push hook catches this, but verify on the release branch after the overlay.
- [ ] Diff under `.github/rulesets/`: any change to `protect-main.json` or `protect-dev.json` has its expected status
  checks reviewed (see
  [`RELEASES-RATIONALE.md` § Status-check context strings](./RELEASES-RATIONALE.md#status-check-context-strings)).
- [ ] Diff under `README.md`: changes are install-path-relevant (e.g. new formula, new tap setup step) or surface a
  user-facing concern. README copy that only affects `dev` reading doesn't belong in a `main` promotion.

### Workflow integrity

- [ ] All `uses:` entries pinned to commit SHAs with trailing version comment. `gh api` SHA-resolution audit script
  catches drift:

  ```bash
  rg -n 'uses:' .github/workflows/ \
    | rg -v '@[0-9a-f]{40}'
  ```

  → Per global CLAUDE.md § Supply-chain pinning. `Homebrew/actions/*` pins carry the CalVer tag they resolve to
  (`# 2026.08.31.1`); Dependabot bumps the SHA weekly on `dev` and the trailing comment moves with it.
- [ ] `actionlint .github/workflows/*.yml` returns clean.
- [ ] `concurrency` groups still match between `tests.yml`, `update-formula.yml`, `publish.yml`. Cross-workflow races on
  the same `update/<formula>/v<version>` head are gated by `update-formula: update-formula` and `publish-bottles:
  publish-bottles` group names; renaming one without the other is a stealth regression.

### Bottle hosting (sample)

The formula's `bottle do` block contains `root_url "https://github.com/<owner>/<repo>/releases/download/v<version>"`.
That URL must resolve to the source repo's GitHub Release assets, not the tap's.

- [ ] Pick the most-recently-bumped formula. Pull its current `root_url` and one bottle filename out of the formula:

  ```bash
  FORMULA=<formula>
  awk '/bottle do/,/end/' "Formula/${FORMULA}.rb"
  ```

- [ ] HEAD-check the root_url + a sample bottle filename. A 404 here means the bot path tagged bottles at a URL the
  source repo never published, or the source release was deleted/renamed after publish. Either is release-blocking.

  ```bash
  curl -fsI "<root_url>/<bottle-filename>" | head -1   # expect HTTP/2 200
  ```

- [ ] `brew install --dry-run brettdavies/tap/<formula>` from a clean cache (`rm -rf ~/.cache/Homebrew/downloads/*` if
  paranoid) on at least one bottle platform. Confirms the download path the user takes.

### Formula audit (sample)

CI runs `brew style`, `brew readall`, and `brew audit` on every push to main, so syntax issues normally surface there. Pre-release,
confirm full `--strict` audit on the formulas you're shipping:

- [ ] For each changed formula in this release: `brew audit --strict --formula <formula>` on a local checkout of the
  release branch. The CI audit is non-strict; strict mode flags things CI lets pass (`bottle do` line ordering, `desc`
  capitalization, license normalization).
- [ ] `brew style --formula <formula>` returns clean. The bot's `brew style --fix` step covers post-`sed` cleanup; human
  edits to formulas (e.g. adding `depends_on`) don't get auto-fixed.
- [ ] Pre-seed sanity: any formula whose `url` still points at `v0.0.0` is intentional (placeholder for a future first
  release) and is excluded from `tests.yml`'s `detect.testing_formulae` output. → See
  [`docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md`](docs/solutions/integration-issues/homebrew-tap-automated-formula-updates-via-dispatch.md)
  if it's there.

### Dispatch contract

Bot path depends on a tight contract with source repos' `release.yml`. Changes to either side that break the contract
fail silently the next time a source repo tags a release.

- [ ] `update-formula.yml` accepts `client_payload.formula`, `client_payload.version`, `client_payload.repo`. Source
  repos' `release.yml` POSTs that exact shape. If you renamed one, audit every source repo.
- [ ] `publish.yml`'s `finalize-release` dispatch back to the source repo POSTs `event_type=finalize-release` with
  `client_payload[tag]`. Source repos' `finalize-release.yml` consumes that shape. Same audit applies.
- [ ] Formula allowlist in `update-formula.yml` matches the set of source repos that dispatch into this tap. Adding a
  new source repo requires adding its formula name to the allowlist.

### Token health

- [ ] `CI_RELEASE_TOKEN` still valid (check its expiration at `https://github.com/settings/personal-access-tokens`). The
  token is used by `update-formula.yml` (open PR), `publish.yml` (`brew pr-pull` + `git-try-push` + finalize dispatch).
  A silently expired token kills the bot path with no surface error in this tap; failures show up as "the upstream
  tagged but no bottles ever appeared".
- [ ] `CI_RELEASE_TOKEN` has Contents R+W and Pull Requests R+W on this tap repo AND on every source repo it dispatches
  `finalize-release` back to.

### Release mechanics sanity

These items duplicate steps in `RELEASES.md` deliberately: easy to skip, expensive to recover from. Confirm explicitly.

- [ ] Branch is named `release/<slug>` (no version prefix; the tap has none). Slug describes what's being promoted, not
  how (no `release/cherry-pick-fixes`).
- [ ] Branch was cut from `origin/main`, NOT from `dev`. Verify:

  ```bash
  git merge-base --is-ancestor origin/main HEAD && echo "(ok)" || echo "rebase: branch is not on top of main"
  ```

- [ ] Triple-diff verification before push: `git diff origin/main..HEAD`, `git diff HEAD..origin/dev` filtered by the
  guarded set (not all of `docs/`, since a directory that ships to `main` would hide a missed path), and `git diff
  origin/dev..origin/main` (sanity) all agree on the intended scope.
- [ ] **Leak check before pushing the release branch.** No guarded path may surface in the diff vs `origin/main`. The
  set resolves from `.github/workflows/guard-main-docs.yml` via `scripts/release/guarded-paths.sh`; never restate the
  pattern inline. If a cherry-pick pulled in guarded paths via rename detection, resolve per
  [`RELEASES.md` § Cherry-pick conflicts on guarded paths](./RELEASES.md#cherry-pick-conflicts-on-guarded-paths).

  ```bash
  GUARDED="$(scripts/release/guarded-paths.sh)"
  git diff origin/main..HEAD --name-only | grep -E "$GUARDED" && echo "LEAKED: reset and redo" || echo "(clean)"
  ```

- [ ] **Every doc this release adds to `main` is meant to ship.** The leak check is blind to a category nobody
  registered. `git diff origin/main..HEAD --diff-filter=A --name-only | grep -E '(^docs/|\.md$)' | grep -Ev "$GUARDED"`
  lists the unguarded additions; each one needs a reason to ship, or it gets registered in the workflow's
  `extra_paths` and removed from the branch.
- [ ] Required status checks defined in `.github/rulesets/protect-main.json` match the actual job names emitted by
  `tests.yml`, `guard-main-docs.yml`, and `guard-main-provenance.yml`. Mismatch produces a stuck-but-green PR.

### Post-merge verification

Run immediately after the `release/<slug> → main` PR merges.

- [ ] `tests.yml` `lint` job on the merge commit returns SUCCESS within ~2 minutes. A failure here usually means the
  promotion shipped a workflow change that lints clean on dev but trips a real GitHub Actions runtime check (rare but
  not impossible).
- [ ] If the promotion touched `update-formula.yml`, `publish.yml`, or any of their dependencies: kick a manual
  `workflow_dispatch` of `update-formula.yml` for the lowest-traffic formula (often `agentnative` while the others are
  quiet) at its current version. Confirms the bot path still produces a clean PR end-to-end. Close the PR without
  merging; this is a smoke test only.
- [ ] `release/<slug>` branch deleted on remote (auto-delete; verify with `gh api
  repos/brettdavies/homebrew-tap/branches`).
- [ ] `dev` is untouched by the merge. A human promotion adds nothing to `main` that `dev` lacks, so there is no
  backport after it (the source repos sync version carriers and `CHANGELOG.md` back; the tap has neither). The
  backport that does exist here follows bot formula bumps, per
  [`RELEASES.md` § After a formula bump lands on main](./RELEASES.md#after-a-formula-bump-lands-on-main). Verify with
  `git log origin/main..origin/dev --oneline`: the dev commits not on main should be the docs-only commits and anything
  intentionally held.

## Related docs

- [`RELEASES.md`](./RELEASES.md): operational runbook this checklist gates.
- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md): release-flow rationale.
- [`README.md`](./README.md): consumer-facing install instructions.
