---
title: "refactor: publish a prebuilt-archive formula without bottles"
type: refactor
status: planned
date: 2026-10-08
---

# Refactor: publish a prebuilt-archive formula without bottles

**Target repos:** brettdavies/homebrew-tap (the pipeline), brettdavies/agent-skills (the release-script template), and
the source repos whose formulas install prebuilt archives: brettdavies/xurl-rs and brettdavies/agentnative-cli, in that
order.

## Goal

A formula that installs the archives its release publishes lands on `main` with no bottle built, signed, or uploaded.
The bump is still tested on every platform the tap covers, and the source repo's release is still finalized by the tap's
callback. A formula that builds its tagged tarball (`bird`) keeps its bottles and the pipeline it has.

## Why

`Formula/xurl-rs.rb` and `Formula/agentnative.rb` name four `releases/download/` archives each, one per platform, and
`bin.install` the binary inside. A bottle of such a formula is the same binary packed again. Producing it costs a bottle
build on four runners, an `attest` job, `brew pr-pull`, `brew pr-upload`, a second commit on `main`, and four more
assets on the source repo's release. It also adds a second trust statement, the tap's attestation over the bottle, for
bytes the source repo already attests and `update-formula.yml` already verifies with
`gh attestation verify --signer-workflow` before it writes each `sha256`.

Without a bottle, `brew install` downloads the archive the formula names and checks it against that `sha256`. Nothing is
compiled: the formula has no build dependency outside `head`.

## What changes for a user

- `brew install brettdavies/tap/xurl-rs` downloads `xurl-rs-<target>.tar.gz` where it poured a bottle. The installed
  files are the same.
- macOS on Intel is served like every other platform. The bottle matrix never covered it, so it already installed from
  the archive.
- Homebrew's install-time attestation check applies to bottles and no longer runs for these formulas. Integrity rests on
  the `sha256` pin, written only after the archive verified against the source repo's release workflow. The README says
  how to verify an archive by hand.

## Key decisions

- **KD1. One definition of "prebuilt".** `update-formula.yml` already decides it: a formula whose `url` lines name
  `releases/download/` archives. That test moves into one script the three workflows call, so `tests.yml` and
  `publish.yml` cannot disagree with the bump about which path a formula takes.
- **KD2. A prebuilt bump is installed and tested, not bottled.** The `bottles` job keeps its four-runner matrix. For a
  prebuilt formula each runner installs the formula from the bump branch, runs `brew test`, and runs the audit
  `brew test-bot` would. U1 first establishes the invocation at the pinned Homebrew: a `brew test-bot` mode that skips
  bottling if one exists, else `brew install`, `brew test`, and `brew audit --strict` directly. No bottle artifact is
  uploaded.
- **KD3. `publish.yml` lands a prebuilt bump through the pull request.** With no bottle there is nothing for `attest`,
  `brew pr-pull`, or `brew pr-upload` to do, and the job stops when `pr-pull` leaves no bottle. The job merges the
  bump PR with its head SHA pinned, so what lands is what the matrix tested, then sends the `finalize-release` dispatch
  and deletes the branch as it does now. `main` gains one commit per bump where it gained two.
- **KD4. The source-built path does not move.** `attest` and the bottle steps run only for a formula KD1 calls
  source-built. Their conditions read the script's answer; their bodies are not edited.
- **KD5. The workflow's name follows what it does.** "Publish bottles" becomes "Publish formula". The release-script
  template's postflight gate looks the run up by that title, so the template accepts both names first, the tap renames
  second, and the template drops the old name once every vendored copy is current.
- **KD6. No migration of what is published.** `update-formula.yml` strips a stale `bottle do` block on every bump, so
  each formula loses its block at its next release. The bottles attached to past releases stay where they are; a
  rollback to a past version still pours them.

## Risks

- **A runner that cannot install the archive.** The Linux archives are static musl builds and the macOS ones are native;
  the matrix proves both on every bump, as it proves the bottle today.
- **A required check that names a bottle job.** `main`'s ruleset lists required checks by job name. U1 keeps the job
  names, or the ruleset file and the live ruleset change with it.
- **A dispatch that never fires.** The source repo's release stays a draft until `finalize-release` arrives. U2 keeps
  the dispatch on the path every formula takes, and the postflight gate reports a missing callback as it does now.
- **Provenance at install time.** Accepted: see "What changes for a user". The archive's attestation is checked once, at
  the bump, by the tap.

## Units

### U1. `tests.yml`: install and test a prebuilt bump without bottling

- **Files:** `.github/workflows/tests.yml`, a new `scripts/formula-form.sh` with its test, `.github/rulesets/` if a job
  name changes.
- **Work:** KD1's script; the `bottles` job branches on it per formula; no `upload-artifact` for a prebuilt formula.
- **Verification:** a scratch bump PR for `xurl-rs` runs the matrix green with no bottle artifact; one for `bird` still
  uploads four.

### U2. `publish.yml`: land a prebuilt bump and finalize

- **Files:** `.github/workflows/publish.yml`.
- **Work:** KD3 and KD4. The branch-name check, the PR lookup, the finalize dispatch, and the branch deletion are shared
  by both paths.
- **Verification:** `workflow_dispatch` against the scratch PR from U1 merges it at the pinned SHA and sends the
  dispatch to a scratch tag's draft release; the same against a `bird` PR publishes bottles as before.

### U3. The tap's documents

- **Files:** `README.md`, `RELEASES.md`.
- **Work:** the pipeline diagram and the step table gain the prebuilt path; "Verifying a bottle" gains the archive form
  (`gh attestation verify <archive> --repo <source repo>`); the rollback recipe names one commit for a prebuilt formula
  and two for a source-built one.

### U4. The release-script template and its copies

- **Files:** `github-repo-setup/` in agent-skills (`postflight.sh` and its tests), then the vendored
  `scripts/release/postflight.sh` in xurl-rs and agentnative-cli.
- **Work:** KD5's first step. The `tap` gate accepts "Publish formula" and "Publish bottles", and its pass line stops
  saying a bottle commit was pushed. Re-vendor verbatim.

### U5. The source repos' documents

- **Files:** in xurl-rs, `RELEASES.md`, `RELEASES-RATIONALE.md`, `crates/xurl-cli/README.md`, and the comments in
  `.github/workflows/release.yml` and `finalize-release.yml`; the same set in agentnative-cli.
- **Work:** the release no longer waits on bottles: it waits on the tap landing the formula. The install section drops
  `brew verify` for a bottle and names the archive check.

### U6. Prove it on a release

- **Work:** the next `xr` release is the first run, the next `anc` release the second. For each: the bump PR's matrix,
  the merge commit on the tap's `main`, the finalized release, `brew install` and `brew test` on macOS arm64 and Linux
  x86_64, and a green postflight.
- **Stop condition:** if the first run strands a draft release, publish it by hand and fix the pipeline before the
  second.

## Definition of done

- A bump of `xurl-rs` and one of `agentnative` each land as one commit on `main` with no bottle built or uploaded, and
  their releases are finalized by the callback.
- A bump of `bird` still publishes signed bottles.
- No document in the tap or in either source repo says a prebuilt formula has bottles.
