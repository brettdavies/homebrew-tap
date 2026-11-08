# Post-release verification: `brettdavies/homebrew-tap`

Operational post-flight checklist. Runs **after** a ship event lands on `main` and verifies the outcome reached
consumers. The tap has two ship paths, each with its own checklist below:

- **Formula bump (bot path)**: a source repo dispatched `update-formula`, which tested the bump and landed it on
  `main`. This is the tap's primary "publish" event.
- **CI/docs release (`release/*` → main)**: a human `release/<slug>` PR promoted workflow, script, or consumer-facing
  doc changes from `dev` to `main`.

Companion to [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md), which gates the release-branch cut. Both follow the
same go/no-go shape: every box is explicit, and an unchecked or red item holds the next release (or motivates a
hotfix). The tap has no `release.yml` tag pipeline and no postflight orchestrator (`scripts/release/` holds only the
drift and guarded-set helpers; the tap is the distribution target, not a versioned source repo), so every gate below is
a manual `gh` / `brew` / `curl` check.

> **A completed watcher is not a green watcher.** `gh run watch <id>` exits 0 when a run finishes regardless of
> outcome. Always confirm with `gh run view <id> --json conclusion --jq .conclusion` returning `success` before
> checking a box.

## Path A: formula bump (bot path)

Run after a source repo's release dispatched `update-formula` into the tap. The chain is one `Update Formula` run
(repository_dispatch): `bump`, then `lint` and four `test` legs, then `land`, which puts the bump on `main` and
dispatches `finalize-release` back to the source repo.

- [ ] **The landing run is green.** `gh run list -R brettdavies/homebrew-tap --workflow update-formula.yml --limit 3`
  shows the run titled `Update <formula> to v<version>`, without `(dry run)`, as `completed`/`success`, and its `land`
  job ran the push and the dispatch (both are skipped only under `dry_run`). Confirm it with
  `gh run view <id> --json conclusion --jq .conclusion`.
- [ ] **The bump landed on `main`.** `git log origin/main --oneline -3 -- Formula/<formula>.rb` shows
  `chore(<formula>): bump to v<version>` at or near the tip, and every `url` line in
  `git show origin/main:Formula/<formula>.rb` names `v<version>`.

### The formula

- [ ] **The formula carries no bottle block.** `git show origin/main:Formula/<formula>.rb | grep -c 'bottle do'` prints
  `0`, and `main` gained one commit for the bump.
- [ ] **Every archive resolves and matches its checksum.** Each `url` the formula names downloads, and its bytes hash to
  the `sha256` pinned under it. `brew fetch --os=all --arch=all` is no substitute: it fetches bottles.

  ```bash
  git show origin/main:Formula/<formula>.rb \
    | awk '/^ *url "/ {u=$2} /^ *sha256 "/ && u {gsub(/"/,"",u); gsub(/"/,"",$2); print $2, u; u=""}' \
    | while read -r sha url; do
        if [ "$(curl -fsSL "$url" | shasum -a 256 | cut -d' ' -f1)" = "$sha" ]; then
          echo "ok ${url##*/}"
        else
          echo "MISMATCH ${url##*/}"
        fi
      done
  ```

- [ ] **`brew install` downloads the archive.** `brew install brettdavies/tap/<formula>` downloads
  `<artifact>-<target>.tar.gz` from the source repo's release, finishes in seconds, and `<binary> --version` reports
  `<version>`. Nothing is compiled.

### Every bump

- [ ] **`finalize-release` dispatched to the source repo.** `update-formula.yml`'s `land` job POSTs `finalize-release`
  back to the source repo after the bump lands.
  `gh run list -R <owner>/<repo> -e repository_dispatch --limit 3` shows a recent
  `finalize-release` run; confirm its conclusion is `success` and the source repo's GitHub Release for `v<version>` is
  published (`gh release view v<version> -R <owner>/<repo> --json isDraft --jq .isDraft` is `false`).
- [ ] **Last-good identifier recorded.** Note the last commit the previous version's bump put on `main` (the earlier
  `chore(<formula>): bump to v<version>` row in `git log origin/main --oneline -- Formula/<formula>.rb`) somewhere
  reachable under incident pressure, so a rollback is a single `git checkout <sha> -- Formula/<formula>.rb`. Commands in
  [`RELEASES.md` § Rollback](./RELEASES.md#rollback).
- [ ] **Rollback path confirmed.** If this bump is bad, restore the last-good formula on `main` through a
  `release/rollback-*` PR first, then backport it to `dev` with the sync script; the fix itself arrives as a new bump
  through the bot path.
- [ ] **`dev` backported.** `dev`'s copy of the formula goes stale the moment the bot ships to `main`. Run
  `./scripts/sync-formulas-to-dev.sh <formula>`, which opens a PR from `main`'s formula state to `dev`; review and
  squash-merge it once CI is green. See
  [`RELEASES.md` § After a formula bump lands on main](./RELEASES.md#after-a-formula-bump-lands-on-main).

## Path B: CI/docs release (`release/*` → main)

Run after a `release/<slug>` → `main` PR merges (workflow, script, or consumer-facing doc changes promoted from `dev`).

- [ ] **`CI` green on `main`.** The push to `main` triggers `CI` (the `lint` job's `brew style`, `readall`, and
  `audit` phases, which validate every formula in the tap). `gh run list -R brettdavies/homebrew-tap --branch main
  --limit 3` shows the post-merge `CI` run `success`. Confirm with `gh run view <id> --json conclusion --jq
  .conclusion`.
- [ ] **The promoted change is live on `main`.** `git diff origin/main..<release-branch-base> --stat` is empty for the
  intended files; what merged matches what the release branch carried. For a workflow change, the live file on `main`
  (`git show origin/main:.github/workflows/<file>`) reflects the new content.
- [ ] **No guarded paths leaked to `main`.** With `GUARDED="$(scripts/release/guarded-paths.sh)"`, `git ls-tree -r
  --name-only origin/main | grep -E "$GUARDED"` returns nothing; `guard-main-docs.yml` should have blocked any
  engineering-doc or dev-only file from reaching `main`. The set resolves from the workflow, never from an inline
  pattern.
- [ ] **Last-good identifier recorded.** The `main` SHA from before the merge (`git rev-parse origin/main` taken
  before clicking merge, or the parent of the release squash) is noted somewhere reachable, so a rollback of a
  workflow or script regression is one `git checkout <sha> -- <path>` on a `release/rollback-*` branch.
- [ ] **Rollback path confirmed.** If the promotion is bad, restore the affected files on `main` first via a
  `release/rollback-*` PR, then land the real fix through `dev` and a fresh `release/<slug>` so `main` reconverges. See
  [`RELEASES.md` § Rollback](./RELEASES.md#rollback).
- [ ] **`dev` untouched by the merge.** `git rev-parse origin/dev` is unchanged from before the merge; the release
  flows only into `main`. `dev` keeps its engineering docs and dev-only files.
- [ ] **`release/<slug>` branch auto-deleted.** `git ls-remote --heads origin "release/*"` returns nothing for the
  merged slug; `delete_branch_on_merge` cleans it up.

## Related docs

- [`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md): pre-cut go/no-go checklist (runs BEFORE this one).
- [`RELEASES.md`](./RELEASES.md): operational runbook for both ship paths.
- [`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md): release-flow rationale.
