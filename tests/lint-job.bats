#!/usr/bin/env bats
# The CI lint job runs every check the pre-push hook adds to it that CI can
# enforce for a contributor whose clone never activated the hooks.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  WORKFLOW="${REPO_ROOT}/.github/workflows/tests.yml"
}

@test "the lint job runs the concurrency-group check, not only lints it" {
  run grep -nE '^ *(run: *)?\./scripts/check-workflow-concurrency\.sh( |$)' "${WORKFLOW}"
  [ "${status}" -eq 0 ] || {
    echo "tests.yml lints scripts/check-workflow-concurrency.sh but never runs it"
    return 1
  }
}
