---
title: "fix: complete post-rename dispatch fix in publish.yml"
type: fix
status: complete
date: 2026-04-29
---

# Fix: complete post-rename dispatch fix in publish.yml

## Overview

PR #50 (merged to `dev` 2026-04-21) replaced a hardcoded `brettdavies/${FORMULA}` source-repo assumption in the `Pull
bottles` step with a `url:`-derived `REPO` value. The same hardcoded assumption survives at the next step — `Finalize
source repo release` — and PR #50's `dev` branch has not yet shipped to `main`. Today's `agentnative-cli` v0.2.0 release
(the first since the `agentnative` → `agentnative-cli` rename) ran against the unfixed `main` and exposed both gaps:
`Pull bottles` succeeded only because GitHub's old-name → new-name redirect happened to follow for asset GETs, and
`Finalize source repo release` POSTed to `repos/brettdavies/agentnative/dispatches` — a slug that now hosts a different,
unrelated repo.

This plan finishes the post-rename fix the same way PR #50 started it (parse owner/repo from the formula's `url:`
field), audits for any remaining hardcoded slugs in this repo, and ships the combined fix to `main` via the established
`release/*` pathway so the next CLI release hits the right source repo automatically.

---

## Problem Frame

- **Symptom (2026-04-29):** `agentnative-cli` v0.2.0 released, bottles built and uploaded, but the source repo's
  `make_latest: true` flip never fired automatically. Manual `gh api repos/brettdavies/agentnative-cli/dispatches` was
  required to recover.
- **Root cause:** `publish.yml`'s `Finalize source repo release` step calls `gh api
  "repos/brettdavies/${FORMULA}/dispatches"`. The formula filename and the source-repo slug are independent identifiers
  — they happened to match before the rename.
- **Why the redirect didn't save us:** GitHub's repo-rename redirect serves GET requests well but is not a guarantee for
  POST. For `repository_dispatch` POSTs in particular, redirects drop auth scope and the request silently no-ops.
- **Why "wait for the redirect to fail" is not safe:** the slug `brettdavies/agentnative` is now a separate live repo.
  Treat the old slug as dead — never as a fallback. The fix must resolve the actual source repo from the formula, not
  from the formula filename.
- **Why this matters now:** future `agentnative-cli` releases will keep failing finalize until the fix lands on `main`.
  Future formulae whose source-repo slug differs from the formula name (third-party tools, repos with `-cli`/`-rs`/`-rb`
  suffixes, etc.) would hit the same bug.

---

## Requirements Trace

- R1. `Finalize source repo release` in `publish.yml` dispatches to the source repo derived from
  `Formula/<formula>.rb`'s `url:` field, not from `${FORMULA}`.
- R2. The fix uses the same `sed`-based parse PR #50 introduced for `Pull bottles` so both steps share one shape — no
  second extraction idiom for reviewers to hold in their head.
- R3. Parse failures fail loudly with the same actionable error message pattern PR #50 uses (no silent no-ops, no
  fallback to the old slug).
- R4. The tap is audited for any other hardcoded `brettdavies/${FORMULA}` source-repo references; any found are
  converted to the parsed-from-`url:` pattern.
- R5. The brettdavies/.github reusable workflows that source repos call (`rust-release.yml`,
  `rust-finalize-release.yml`) are confirmed clean and noted in the plan; no edits if clean.
- R6. The combined fix (PR #50's pending dev work + this plan's additions) ships to tap `main` via a
  `release/<topic-slug>` branch, mirroring the convention PRs #50/#53 used.
- R7. End-to-end verification proves the next CLI release's finalize dispatch fires automatically against
  `brettdavies/agentnative-cli` — no manual `gh api` recovery.

---

## Scope Boundaries

- Not changing the `update-formula.yml` direction (source repo → tap). That direction works: the source repo's reusable
  `rust-release.yml` hardcodes `repos/brettdavies/homebrew-tap/dispatches`, which is correct by name.
- Not introducing a new abstraction (e.g., a composite action) for the `REPO` parse just to share it across two steps in
  one file. PR #50's inline `sed` is the established pattern; duplicating it once is fine, and a composite is
  over-engineering until a third call site appears.
- Not changing the formula `url:` shape or any source-repo's release pipeline. The formula file is the contract.
- Not adding broader CI redesign work (e.g., moving dispatch identification to a structured metadata file). Out of
  scope; would block the launch-eve fix this plan unblocks.
- Not touching the new `brettdavies/agentnative` (spec) repo's workflows. That repo's existence is acknowledged as the
  cause of the broken redirect; no work is needed there.

---

## Context & Research

### Relevant Code and Patterns

- `.github/workflows/publish.yml` (on `dev`) — the file with both the already-fixed `Pull bottles` step and the
  still-broken `Finalize source repo release` step. The two steps are adjacent; the `REPO` parse is currently scoped to
  `Pull bottles` only.
- The PR #50 idiom (verbatim from `dev`):

  ```yaml
  REPO=$(sed -nE 's|^  url "https://github\.com/([^/]+/[^/]+)/archive/.*|\1|p' \
    "Formula/${FORMULA}.rb" | head -n1)
  if [ -z "$REPO" ]; then
    echo "::error::Could not parse owner/repo from Formula/${FORMULA}.rb url field"
    exit 1
  fi
  ```

- `brettdavies/.github/.github/workflows/rust-release.yml` — agentnative-cli's release pipeline caller. Dispatches to
  tap by hardcoded `repos/brettdavies/homebrew-tap/dispatches`. Correct by name; no change.
- `brettdavies/.github/.github/workflows/rust-finalize-release.yml` — the source-side handler for the dispatch. Uses
  `${{ github.repository }}` (i.e., the receiving repo's own slug). Correct; no change.

### Institutional Learnings

- Same class as `agentnative-cli@7f4f257` (`chore(changelog): fix cliff.toml repo name post-rename`). Renames leak
  through hardcoded references in CI scaffolding; redirects mask the breakage until a POST or other
  non-redirect-following call is made.
- PR #50's commit message captured the future-fragility note already: *"The Homebrew dispatch chain assumes formula name
  == crate name == repo name. If a future tool breaks this coupling, add an optional `formula` input … and update
  homebrew-tap/publish.yml."* This plan is the second half of that note's resolution — applied to the dispatch step
  instead of via a new optional input.

### External References

- None required. The fix idiom is established in this repo (PR #50). No external docs needed.

---

## Key Technical Decisions

- **Mirror PR #50's inline `sed` parse rather than introduce a composite action or shell helper.** The parse is two
  non-trivial lines duplicated once. A composite would force the caller to checkout-then-use, which costs more reviewer
  attention than the duplicate. If a third call site appears, revisit.
- **Fail loudly on parse failure.** Match PR #50's `::error::Could not parse owner/repo …` message verbatim. Silent
  fallback to the old slug is what hid this bug for 8 days.
- **Ship via `release/<topic-slug>` branch, not `release/v<version>`.** The tap's existing pattern (PRs #50, #53, #54)
  uses topic-named release branches because the tap doesn't carry a `version` of its own. Match.
- **Bundle PR #50's pending dev work into the same release.** PR #50 has been on `dev` for 8 days without a release;
  shipping the full set together (rather than two separate release-branch PRs) keeps the post-rename fixes atomic from
  main's perspective.

---

## Open Questions

### Resolved During Planning

- *Should the parse be extracted to a composite action?* No. See Key Technical Decisions.
- *Does any source repo need changes?* No. The reusable workflows in `brettdavies/.github` use `${{ github.repository
  }}` (correct). Source-repo `release.yml` files only dispatch inbound to tap by name (correct).

### Deferred to Implementation

- The exact composition of the `release/<topic-slug>` branch — straight cherry-pick vs.
  branch-from-`main`-and-port-the-`dev`-diff. Decide at execution based on whether `dev` has drifted further during plan
  review.
- Whether to wait for an organic CLI release to verify R7 or trigger a smoke release. Likely organic — agentnative-cli
  will hit a bugfix release before long, and the fix is low enough risk that catching the next real release is
  acceptable.

---

## Implementation Units

- U1. **Extend PR #50's `REPO` parse to the `Finalize source repo release` step**

**Goal:** Replace the hardcoded `repos/brettdavies/${FORMULA}/dispatches` with a dispatch to the source repo derived
from the formula's `url:` field, mirroring the `Pull bottles` step.

**Requirements:** R1, R2, R3.

**Dependencies:** None.

**Files:**

- Modify: `.github/workflows/publish.yml` (the `Finalize source repo release` step in the `publish` job).

**Approach:**

- Re-derive `REPO` inside the `Finalize source repo release` step using the exact `sed` expression from `Pull bottles`.
- The two `REPO` derivations are intentionally independent (one per step) — workflow steps do not share local shell
  variables, and exporting via `$GITHUB_ENV` from `Pull bottles` would couple the two steps' lifecycles in a way that
  makes the failure mode worse, not better. Keep them parallel.
- Replace the dispatch line:
- Before: `gh api "repos/brettdavies/${FORMULA}/dispatches" …`
- After: `gh api "repos/${REPO}/dispatches" …`
- Match PR #50's failure message verbatim: `::error::Could not parse owner/repo from Formula/${FORMULA}.rb url field` →
  `exit 1`.
- Leave the `event_type=finalize-release` payload unchanged. The dispatch contract is already correct; only the
  destination was wrong.

**Patterns to follow:**

- `.github/workflows/publish.yml` `Pull bottles` step (PR #50, commit `e662946f`).

**Test scenarios:**

- Happy path. `Formula/agentnative.rb` with `url
  "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.2.0.tar.gz"` → `REPO=brettdavies/agentnative-cli`
  → POST hits the agentnative-cli repo's dispatches endpoint → `Finalize Release` workflow run appears on
  agentnative-cli within ~30s.
- Edge case. A formula whose `url:` points outside GitHub (e.g., a future formula with a GitLab-hosted source) → the
  `sed` regex fails to match → `REPO` is empty → step exits 1 with the actionable error. (No formula like this exists
  today; the test confirms the fail- loud behavior.)
- Error path. A formula whose `url:` line is missing or malformed → empty `REPO` → fail loud with the same error. (Same
  surface as Edge case; called out separately because the *intent* — bad formula data vs. unsupported host — differs
  even if the failure path is one branch.)
- Integration. Run a real CLI release end-to-end after this change reaches tap `main`; verify the source repo's
  `Finalize Release` workflow fires automatically (no manual `gh api` recovery). Covered as R7 verification in U4.

**Verification:**

- The diff shows only the `Finalize source repo release` step changed: the `REPO=$(sed …)` block inserted before `gh api
  …`, and the dispatch URL changed from `repos/brettdavies/${FORMULA}/dispatches` to `repos/${REPO}/dispatches`.
- `actionlint` (or whatever the existing CI lint covers) passes.

---

- U2. **Audit the tap for any other hardcoded `brettdavies/${FORMULA}` or `brettdavies/agentnative` source-repo
  references**

**Goal:** Confirm U1 is the only place the post-rename assumption survives in this repo, and convert any remaining hits
to the parsed-from-`url:` pattern.

**Requirements:** R4.

**Dependencies:** U1 (so the canonical pattern is in place to copy from).

**Files:**

- Modify: any file flagged by the audit. Expected: zero. If non-zero, the audit's findings amend U1's verification list
  rather than adding a separate change set.

**Approach:**

- Grep the working tree for the patterns that could carry the assumption:
- `brettdavies/\${FORMULA}` and `brettdavies/$FORMULA` (literal in YAML, shell, or docs).
- `brettdavies/agentnative` (verbatim — the slug that's now the spec repo, not the CLI).
- `repos/brettdavies/.*dispatches` (tighter scan for any other dispatch sites).
- Examine `.github/workflows/*.yml`, `Formula/*.rb`, `README.md`, `docs/`, and any scripts.
- For any hit that's a real source-repo reference, convert to the `REPO=$(sed …)` parse pattern (or, for non-workflow
  contexts like docs, update the prose to reference `agentnative-cli`).
- For any hit that's incidental (commit messages in CHANGELOG-style docs referring to the pre-rename history) — leave it
  alone. Historical references stay historical.

**Patterns to follow:**

- The same `REPO=$(sed …)` block from U1.

**Test scenarios:**

- Happy path. Audit finds zero hits beyond U1's already-fixed step → U2's diff is empty; the unit's verification is the
  audit log itself, captured in the PR description.
- Edge case. Audit surfaces a doc/README reference to the pre-rename slug → judgment call per the criteria above;
  document the call in the PR.

**Verification:**

- The audit grep results are pasted into the PR description. Reviewer can re-run the same greps locally and reach the
  same set.

---

- U3. **Confirm cross-repo callers are clean (read-only)**

**Goal:** Document that source-repo callers of the homebrew dispatch chain are not affected by this bug, so reviewers
know U1+U2 close the loop without needing edits in `brettdavies/.github`, `agentnative-cli`, or other source repos.

**Requirements:** R5.

**Dependencies:** None (read-only confirmation).

**Files:**

- None modified. This unit produces a paragraph in the PR description, not a code change.

**Approach:**

- Confirm the two reusable workflows in `brettdavies/.github`:
- `rust-release.yml` — dispatches to tap via `repos/brettdavies/homebrew-tap/dispatches` (hardcoded by name, correct).
- `rust-finalize-release.yml` — uses `${{ github.repository }}` (the receiving repo's own slug, correct).
- Confirm `agentnative-cli`'s `release.yml` calls `brettdavies/.github/.github/workflows/rust-release.yml@main` and adds
  no extra dispatch hardcoding.
- Confirm the source-repo handler `agentnative-cli/.github/workflows/finalize-release.yml` calls
  `brettdavies/.github/.github/workflows/rust-finalize-release.yml@main` only.

**Test scenarios:**

- Test expectation: none — read-only confirmation, no behavioral change. The PR description carries the audit notes so
  the next person hitting a post-rename issue elsewhere sees what's already been verified.

**Verification:**

- The PR description includes the audit notes for the four workflow paths above with links to the lines/SHAs reviewed.

---

- U4. **Ship the combined fix to tap `main` via `release/<topic-slug>` PR**

**Goal:** Land U1 + U2 (and PR #50's pending `dev` work, since it hasn't shipped to `main`) on `main` through the tap's
established release pathway, so the next CLI release picks up the fix automatically.

**Requirements:** R6, R7.

**Dependencies:** U1, U2, U3 (all merged or recorded on `dev`).

**Files:**

- Modify: as carried by U1 + U2 + PR #50's `dev` diff. No new file changes in this unit beyond what those carry.

**Approach:**

- Branch `release/<topic-slug>` from `origin/main` (matching PR #50/#53/#54 convention — topic-named, no version prefix
  because the tap has no version of its own).
- Topic slug suggestion: `release/post-rename-finalize-dispatch` or `release/publish-finalize-dispatch-fix`. Pick one at
  execution; the slug is for human readability of the merge commit.
- Cherry-pick the relevant `dev` commits onto the branch:
- PR #50's commit (`e662946f` — `Pull bottles` `--root-url` parse).
- U1's commit (the new `Finalize source repo release` parse).
- U2's commit, if non-empty.
- Verify `git diff origin/main --stat` includes only `.github/workflows/publish.yml` (and possibly trivial doc edits if
  U2 found any). If anything else surfaces, abort and redo the cherry-pick — `dev` may carry unrelated drift this branch
  should not include.
- Push, open PR titled `fix: complete post-rename dispatch fix in publish.yml`. Body links this plan and the original
  incident (`agentnative-cli` v0.2.0 launch).
- CI green → squash-merge to `main` (admin override if branch protection requires review on the tap; same as PR #50/#53
  pattern).

**Patterns to follow:**

- PR #50 (`release/<topic-slug>` flow, squash-merge convention).
- PR #53 (`chore(agentnative): rewrite v0.1.1 bottle root_url to renamed repo` — closest prior post-rename fix on this
  repo).

**Test scenarios:**

- Integration (Covers R7). After merge to `main`, the next `agentnative-cli` release triggers tap `update-formula` →
  `Publish bottles` → `Finalize source repo release`. The source repo's `Finalize Release` workflow run appears
  automatically; no manual `gh api repos/brettdavies/agentnative-cli/dispatches` is needed; `/releases/latest` flips to
  the new version without intervention.

**Verification:**

- The merge commit on `main` matches the conventional `fix:` prefix.
- A subsequent CLI release (organic or smoke-tested) finalizes without manual intervention.
- The tap's `gh run list` shows the chained `Publish bottles` → `Finalize source repo release` step exit-zeroing with
  the dispatch hitting the correct source repo (visible in the step's `gh api` log line).

---

## System-Wide Impact

- **Interaction graph:** Tap `Publish bottles` → tap `Finalize source repo release` (changed) → source repo's
  `repository_dispatch` → source repo's `Finalize Release` workflow → `make_latest: true` flip on the GitHub Release. No
  other consumers.
- **Error propagation:** `Finalize source repo release` step previously exit-zeroed on a silently-misdirected dispatch.
  After this change it exit-1s on parse failure (correct fail- loud), and exit-zeros on a successfully-routed dispatch.
  The receiving repo's workflow surface is unchanged.
- **State lifecycle risks:** None new. The dispatch is idempotent on the receiving side (`rust-finalize-release.yml`
  succeeds whether the release is still draft or already published).
- **API surface parity:** `Pull bottles` and `Finalize source repo release` will both derive `REPO` from the formula's
  `url:` field. They become symmetric; reviewer no longer has to hold "step A uses parsed REPO, step B uses formula
  slug" in their head.
- **Integration coverage:** Verified by U4's end-to-end smoke test against the next CLI release.
- **Unchanged invariants:**
- `event_type=finalize-release` and `client_payload[tag]=${VERSION}` payload — unchanged.
- `update-formula.yml` (source repo → tap inbound) — unchanged.
- The formula file's `url:` shape — unchanged.
- The `brettdavies/.github` reusable workflows — unchanged (already correct).

---

## Risks & Dependencies

| Risk                                                                                                   | Mitigation                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The `sed` regex doesn't match a future non-GitHub source URL.                                          | Plan U1's Edge case test scenario covers this — the step exits 1 with the same actionable error PR #50 uses. The tap can revisit with a more general parser if/when a non-GitHub formula lands; today there are none.              |
| A malicious or accidentally-malformed formula `url:` could redirect the dispatch to an arbitrary repo. | Formula files merge to `main` only via PR review. The `url:` field is human-reviewed at every formula update, so the trust boundary already exists at the merge step. The dispatch doesn't widen it.                               |
| `dev` drifts further between plan-write and U4 execution, complicating the cherry-pick.                | The audit in U2 also serves as a drift detector; rerun before cutting the release branch.                                                                                                                                          |
| The next CLI release happens before this fix lands, requiring another manual `gh api` recovery.        | Acceptable. The manual recovery is one command and it's already documented in `~/.gstack/projects/brettdavies-agentnative/cold-device-verification-2026-04-29.md`. Land the fix before the *third* release, not before the second. |
| Reviewer fatigue on "yet another post-rename fix".                                                     | The PR body links this plan and PR #50 explicitly so the second half is visibly the completion of the first half, not a parallel change.                                                                                           |

---

## Documentation / Operational Notes

- After U4 merges to `main`, add a one-line note to the tap's `RELEASES.md` (or equivalent if it exists) stating that
  formula and source-repo slugs are independent identifiers and the source-repo slug is always derived from the
  formula's `url:` field. Optional polish; not blocking.
- Add a retro item to the `agentnative-cli` launch retro pointing at this plan as the permanent close-out for the
  launch-eve dispatch incident.

---

## Sources & References

- Today's incident log: `~/.gstack/projects/brettdavies-agentnative/cold-device-verification-2026-04-29.md` (final
  section, "post-rename dispatch bug").
- Prior partial fix: PR #50 — *"ci: derive owner/repo from formula url, not formula name"*, merged to `dev` 2026-04-21,
  commit `e662946f`.
- Closest prior post-rename fix on this repo: PR #53 — *"chore(agentnative): rewrite v0.1.1 bottle root_url to renamed
  repo"*.
- Companion fix elsewhere: `agentnative-cli@7f4f257` — *"chore(changelog): fix cliff.toml repo name post-rename
  (agentnative → agentnative-cli)"*.
- Reusable workflow handler (already correct): `brettdavies/.github/.github/workflows/rust-finalize-release.yml`.
- Reusable workflow caller (already correct): `brettdavies/.github/.github/workflows/rust-release.yml`.
