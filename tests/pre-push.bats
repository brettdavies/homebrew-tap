#!/usr/bin/env bats
# scripts/hooks/pre-push skips a push that only deletes remote refs. Each test
# runs the hook with git as the only tool on PATH, so a hook that reaches its
# checks stops at the first missing tool instead of running them.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  HOOK="${REPO_ROOT}/scripts/hooks/pre-push"
  BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${BIN}"
  ln -s "$(command -v git)" "${BIN}/git"
  ZERO_SHA1="$(printf '0%.0s' {1..40})"
  ZERO_SHA256="$(printf '0%.0s' {1..64})"
  SHA="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
  cd "${REPO_ROOT}" || return 1
}

run_hook() {
  run env PATH="${BIN}" HOOK_STDIN_WAIT_SECONDS=1 "${BASH}" "${HOOK}" origin https://github.com/brettdavies/homebrew-tap.git
}

@test "a push that only deletes exits 0 without running a check" {
  run_hook <<EOF
(delete) ${ZERO_SHA1} refs/heads/gone ${SHA}
(delete) ${ZERO_SHA256} refs/heads/gone-too ${SHA}
EOF
  [ "${status}" -eq 0 ]
  [ "${output}" = "Nothing to check: the push only deletes." ]
}

@test "a push that delivers a commit runs the checks" {
  run_hook <<EOF
refs/heads/feat ${SHA} refs/heads/feat ${ZERO_SHA1}
EOF
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"brew not on PATH"* ]]
}

@test "a delete alongside a commit runs the checks" {
  run_hook <<EOF
(delete) ${ZERO_SHA1} refs/heads/gone ${SHA}
refs/heads/feat ${SHA} refs/heads/feat ${ZERO_SHA1}
EOF
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"brew not on PATH"* ]]
}

@test "a ref line with no sha runs the checks" {
  run_hook <<EOF
(delete) ${ZERO_SHA1} refs/heads/gone ${SHA}
refs/heads/feat
EOF
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"brew not on PATH"* ]]
}

@test "a final delete line with no newline counts as a delete" {
  run_hook < <(printf '(delete) %s refs/heads/gone %s' "${ZERO_SHA1}" "${SHA}")
  [ "${status}" -eq 0 ]
  [ "${output}" = "Nothing to check: the push only deletes." ]
}

@test "a delete then a final commit line with no newline runs the checks" {
  run_hook < <(printf '(delete) %s refs/heads/gone %s\nrefs/heads/feat %s refs/heads/feat %s' \
    "${ZERO_SHA1}" "${SHA}" "${SHA}" "${ZERO_SHA1}")
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"brew not on PATH"* ]]
}

@test "no ref lines runs the checks" {
  run_hook </dev/null
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"brew not on PATH"* ]]
}

@test "a stdin left open past the timeout runs the checks" {
  run_hook < <(
    printf '(delete) %s refs/heads/gone %s\n' "${ZERO_SHA1}" "${SHA}"
    sleep 2
  )
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"brew not on PATH"* ]]
}
