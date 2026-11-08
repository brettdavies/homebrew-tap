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

@test "land waits for the bump, the lint job, and every test leg" {
  run job_block land
  [[ "${output}" == *"needs: [bump, lint, test]"* ]] || {
    echo "land does not need bump, lint, and test"
    return 1
  }
  [[ "${output}" != *"if:"*"always()"* && "${output}" != *"if:"*"!cancelled()"* ]] || {
    echo "land runs after a failed need"
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
    echo "bump has no source-built-formula refusal"
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
