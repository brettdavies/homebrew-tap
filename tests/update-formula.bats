#!/usr/bin/env bats
# update-formula.yml pushes a bump to `main` with no pull request, so its jobs
# are the only gate between a release and the tap. These hold it to that.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  WORKFLOW="${REPO_ROOT}/.github/workflows/update-formula.yml"
}

# Prints one job's block: from its `  <job>:` line to the next job.
job_block() {
  awk -v job="$1" '
    $0 ~ "^  " job ":$" { in_job = 1; next }
    in_job && /^  [a-z][a-z0-9_-]*:$/ { exit }
    in_job { print }
  ' "${WORKFLOW}"
}

# Prints one step's block within a job: from its `- name:` line to the next step.
step_block() {
  job_block "$1" | awk -v step="$2" '
    $0 ~ "^      - name: " step "$" { in_step = 1; print; next }
    in_step && /^      - / { exit }
    in_step { print }
  '
}

# Prints one step's `run:` body without its indent, to run as a script.
step_run() {
  step_block "$1" "$2" | awk '
    /^        run: \|$/ { in_run = 1; next }
    in_run && /^        [a-zA-Z_-]+:/ { exit }
    in_run { sub(/^          /, ""); print }
  '
}

# Writes a gh stub to $1/gh. `release download` writes each --pattern file,
# `attestation verify` fails for the asset named in STUB_UNATTESTED and for any
# call without the expected signer, and `api` logs its arguments.
write_gh_stub() {
  cat >"$1/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "release download")
    dir="" patterns=()
    shift 2
    while [ $# -gt 0 ]; do
      case "$1" in
        --dir) dir="$2"; shift 2 ;;
        --pattern) patterns+=("$2"); shift 2 ;;
        *) shift ;;
      esac
    done
    for f in "${patterns[@]}"; do echo "archive $f" >"${dir}/${f}"; done
    ;;
  "attestation verify")
    [[ " $* " == *" --signer-workflow brettdavies/.github/.github/workflows/rust-release.yml "* ]] || {
      echo "no attestation signed by the expected workflow" >&2
      exit 1
    }
    [[ -n "${STUB_UNATTESTED:-}" && "$3" == *"${STUB_UNATTESTED}" ]] && { echo "no attestations found" >&2; exit 1; }
    exit 0
    ;;
  "api "*) echo "$*" >>"${STUB_LOG}" ;;
  *) echo "gh stub: unhandled $*" >&2; exit 1 ;;
esac
STUB
  chmod +x "$1/gh"
}

@test "land waits for the bump, the lint job, and every test leg" {
  needs=$(job_block land | grep -E '^    needs:')
  have=$(sed -E 's/.*\[(.*)\].*/\1/; s/[ ,]+/\n/g' <<<"${needs}" | sort | paste -sd ' ' -)
  [ "${have}" = "bump lint test" ] || {
    echo "land needs '${have}' (${needs#"${needs%%[! ]*}"}), not bump, lint, and test"
    return 1
  }
  # Any job-level condition, `always()` or a result test alike, can run land
  # past a need that failed.
  if job_block land | grep -qE '^    if:'; then
    echo "land carries a job-level if:, which can run it after a failed need"
    return 1
  fi
}

@test "no job before land continues past its own failure" {
  for job in bump lint test; do
    if job_block "${job}" | grep -q 'continue-on-error'; then
      echo "${job} sets continue-on-error, so land would run after it failed"
      return 1
    fi
  done
}

@test "lint, every test leg, and land use the formula bump uploaded" {
  for job in lint test; do
    block=$(step_block "${job}" "Download the bumped formula")
    [[ "${block}" == *"name: formula"* && "${block}" == *"path: Formula"* ]] || {
      echo "${job} does not download the bumped formula into Formula/"
      return 1
    }
  done
  run step_block land "Commit the bump"
  # shellcheck disable=SC2016 # the workflow's own text, matched literally
  [[ "${output}" == *'bumped="${RUNNER_TEMP}/formula/${FORMULA}.rb"'* ]] || {
    echo "land does not commit the formula it downloaded"
    return 1
  }
}

@test "dry_run comes from the dispatch input" {
  # shellcheck disable=SC2016 # the workflow's own text, matched literally
  grep -qxF '  DRY_RUN: ${{ inputs.dry_run || false }}' "${WORKFLOW}" || {
    echo "DRY_RUN does not read inputs.dry_run, so a dry run may push"
    return 1
  }
}

@test "a failed test leg cancels no other leg" {
  run job_block test
  [[ "${output}" == *"fail-fast: false"* ]] || {
    echo "the test matrix does not set fail-fast: false"
    return 1
  }
}

@test "the test legs run on the platforms tests.yml tests" {
  ours=$(job_block test | grep -E '^ +os: \[')
  theirs=$(grep -E '^ +os: \[' "${REPO_ROOT}/.github/workflows/tests.yml")
  [ -n "${theirs}" ] && [ "${ours}" = "${theirs}" ] || {
    echo "update-formula.yml tests on '${ours}', tests.yml on '${theirs}'"
    return 1
  }
}

@test "a dry run skips the push and the finalize dispatch" {
  for step in "Push commits" "Finalize source repo release"; do
    run step_block land "${step}"
    [ -n "${output}" ] || {
      echo "land has no step named ${step}"
      return 1
    }
    [[ "${output}" == *"if: env.DRY_RUN != 'true'"* ]] || {
      echo "${step} runs under dry_run"
      return 1
    }
  done
}

@test "the bump refuses a source-built formula under its code" {
  run job_block bump
  [[ "${output}" == *"scripts/formula-form.sh"* ]] || {
    echo "bump does not read the form"
    return 1
  }
  [[ "${output}" == *"::error title=source-built-formula::"* ]] || {
    echo "the source-built refusal has no ::error title=source-built-formula:: annotation"
    return 1
  }
}

@test "a run that pushes refuses to run from a branch other than main" {
  run step_block bump "Validate inputs"
  # shellcheck disable=SC2016 # the workflow's own text, matched literally
  [[ "${output}" == *'[ "$DRY_RUN" != true ] && [ "$GITHUB_REF" != refs/heads/main ]'* ]] || {
    echo "Validate inputs does not refuse a pushing run off main"
    return 1
  }
  [[ "${output}" == *"::error title=push-from-branch::"* ]] || {
    echo "the branch refusal has no ::error title=push-from-branch:: annotation"
    return 1
  }
}

@test "every coded annotation links its own heading in RELEASES.md" {
  failures=0
  while IFS= read -r line; do
    code=$(sed -nE 's/.*::error title=([a-z0-9]+(-[a-z0-9]+)+)::.*/\1/p' <<<"${line}")
    [ -n "${code}" ] || continue
    if [[ "${line}" != *"\${DOCS}#${code}\""* ]]; then
      echo "the ${code} annotation does not end with a link to \${DOCS}#${code}"
      failures=$((failures + 1))
    fi
    if ! grep -qxF "#### \`${code}\`" "${REPO_ROOT}/RELEASES.md"; then
      echo "RELEASES.md has no #### \`${code}\` heading"
      failures=$((failures + 1))
    fi
  done < <(grep -F '::error title=' "${WORKFLOW}")
  [ "${failures}" -eq 0 ]
}

@test "the docs link names the run's own commit" {
  # shellcheck disable=SC2016 # the workflow's own text, matched literally
  grep -qxF '  DOCS: ${{ github.server_url }}/${{ github.repository }}/blob/${{ github.sha }}/RELEASES.md' "${WORKFLOW}" || {
    echo "DOCS does not link RELEASES.md at the run's commit, so a branch run's link can miss its heading"
    return 1
  }
}

@test "the push shares publish.yml's concurrency group" {
  run job_block land
  [[ "${output}" == *"group: publish-formula"* ]] || {
    echo "land is not in the publish-formula group"
    return 1
  }
  run grep -c '^  group: publish-formula$' "${REPO_ROOT}/.github/workflows/publish.yml"
  [ "${output}" = 1 ] || {
    echo "publish.yml no longer holds the publish-formula group"
    return 1
  }
}

@test "an archive that does not verify stops the bump before any checksum" {
  T="${BATS_TEST_TMPDIR}"
  mkdir -p "${T}/bin" "${T}/run/Formula" "${T}/tmp"
  write_gh_stub "${T}/bin"
  step_run bump "Verify release archives and compute SHA256" >"${T}/verify.sh"
  signer=$(step_block bump "Verify release archives and compute SHA256" | sed -nE 's/^ +SIGNER: (.*)$/\1/p')
  cp "${REPO_ROOT}/Formula/xurl-rs.rb" "${T}/run/Formula/"
  cd "${T}/run"
  export PATH="${T}/bin:${PATH}" FORMULA=xurl-rs VERSION=4.6.0 REPO=brettdavies/xurl-rs SIGNER="${signer}" \
    GITHUB_RUN_ID=1 GITHUB_REPOSITORY=brettdavies/homebrew-tap DOCS=https://example.invalid/RELEASES.md

  RUNNER_TEMP="${T}/tmp" run bash "${T}/verify.sh"
  [ "${status}" -eq 0 ] || { echo "${output}"; return 1; }
  [ "$(wc -l <"${T}/tmp/archives.sha256")" -eq 4 ]

  mkdir "${T}/tmp2"
  STUB_UNATTESTED=x86_64-unknown-linux-musl.tar.gz RUNNER_TEMP="${T}/tmp2" run bash "${T}/verify.sh"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"::error title=archive-not-attested::1 of 4 archives"*"x86_64-unknown-linux-musl.tar.gz"* ]]
  [ ! -e "${T}/tmp2/archives.sha256" ]
}

@test "a pushing run off main stops, and a dry run off main or a run on main passes the check" {
  step_run bump "Validate inputs" >"${BATS_TEST_TMPDIR}/validate.sh"
  cd "${REPO_ROOT}"
  validate() {
    DRY_RUN="$1" GITHUB_REF="$2" GITHUB_REF_NAME="${2#refs/heads/}" FORMULA=xurl-rs VERSION=4.6.0 \
      REPO=brettdavies/xurl-rs GITHUB_REPOSITORY=brettdavies/homebrew-tap DOCS=https://example.invalid/RELEASES.md \
      bash "${BATS_TEST_TMPDIR}/validate.sh"
  }
  run validate false refs/heads/feat/x
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"::error title=push-from-branch::"* ]]
  run validate true refs/heads/feat/x
  [ "${status}" -eq 0 ] || { echo "${output}"; return 1; }
  run validate false refs/heads/main
  [ "${status}" -eq 0 ] || { echo "${output}"; return 1; }
}

# A tap whose main holds Formula/demo.rb at 1.0.0, a checkout of it at the
# run's commit, and the bumped file at 1.1.0 where land downloads it.
land_fixture() {
  T="${BATS_TEST_TMPDIR}"
  mkdir -p "${T}/bin" "${T}/tmp/formula"
  write_gh_stub "${T}/bin"
  step_run land "Commit the bump" >"${T}/commit.sh"
  step_run land "Finalize source repo release" >"${T}/finalize.sh"
  git init --quiet --bare --initial-branch=main "${T}/origin.git"
  git clone --quiet "${T}/origin.git" "${T}/seed" 2>/dev/null
  cd "${T}/seed" || return 1
  git config user.name test && git config user.email test@example.invalid && git config commit.gpgsign false
  git checkout --quiet -b main
  mkdir Formula && printf 'class Demo\n  version "1.0.0"\nend\n' >Formula/demo.rb && echo other >Formula/other.rb
  git add -A && git commit --quiet -m seed && git push --quiet origin main
  git clone --quiet "${T}/origin.git" "${T}/work"
  git -C "${T}/work" config user.name test
  git -C "${T}/work" config user.email test@example.invalid
  git -C "${T}/work" config commit.gpgsign false
  printf 'class Demo\n  version "1.1.0"\nend\n' >"${T}/tmp/formula/demo.rb"
  GITHUB_SHA="$(git -C "${T}/work" rev-parse HEAD)"
  export PATH="${T}/bin:${PATH}" STUB_LOG="${T}/gh.log" FORMULA=demo VERSION=1.1.0 REPO=o/demo \
    GITHUB_REF_NAME=main GITHUB_SHA RUNNER_TEMP="${T}/tmp" \
    GITHUB_OUTPUT="${T}/output" GITHUB_SERVER_URL=https://github.com GITHUB_REPOSITORY=o/tap GITHUB_RUN_ID=1 \
    DOCS=https://example.invalid/RELEASES.md
  : >"${GITHUB_OUTPUT}"
}

# Lands a commit on origin's main from the seed clone: seed_main <file> <content>.
seed_main() {
  printf '%s\n' "$2" >"${T}/seed/$1"
  git -C "${T}/seed" commit --quiet -am "$1" && git -C "${T}/seed" push --quiet origin main
}

@test "land commits the bump when main's formula is the run's" {
  land_fixture
  seed_main Formula/other.rb "another formula's bump"
  cd "${T}/work" && run bash "${T}/commit.sh"
  [ "${status}" -eq 0 ] || { echo "${output}"; return 1; }
  grep -qx 'changed=true' "${GITHUB_OUTPUT}"
  [ "$(git log -1 --format=%s)" = "chore(demo): bump to v1.1.0" ]
  cmp -s Formula/demo.rb "${T}/tmp/formula/demo.rb"
}

@test "land commits nothing when main already holds the bumped file" {
  land_fixture
  seed_main Formula/demo.rb "$(cat "${T}/tmp/formula/demo.rb")"
  cd "${T}/work" && run bash "${T}/commit.sh"
  [ "${status}" -eq 0 ] || { echo "${output}"; return 1; }
  grep -qx 'changed=false' "${GITHUB_OUTPUT}"
  [ "$(git rev-parse HEAD)" = "${GITHUB_SHA}" ]
}

@test "land stops as formula-moved when main's formula changed after the run's commit" {
  land_fixture
  seed_main Formula/demo.rb "$(printf 'class Demo\n  version "1.0.0"\n  desc "edited"\nend')"
  cd "${T}/work" && run bash "${T}/commit.sh"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"::error title=formula-moved::Formula/demo.rb on main changed after this run's commit"* ]]
  [ "$(git rev-parse HEAD)" = "${GITHUB_SHA}" ]
}

@test "the finalize dispatch goes out only when main holds the file every check ran on" {
  land_fixture
  seed_main Formula/demo.rb "$(cat "${T}/tmp/formula/demo.rb")"
  cd "${T}/work" && run bash "${T}/finalize.sh"
  [ "${status}" -eq 0 ] || { echo "${output}"; return 1; }
  grep -q 'repos/o/demo/dispatches' "${STUB_LOG}"

  : >"${STUB_LOG}"
  seed_main Formula/demo.rb "$(printf 'class Demo\n  version "1.1.0"\n  desc "merged"\nend')"
  run bash "${T}/finalize.sh"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"::error title=formula-moved::Formula/demo.rb on main is not the file"* ]]
  [ ! -s "${STUB_LOG}" ]
}
