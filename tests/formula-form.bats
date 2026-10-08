#!/usr/bin/env bats
# scripts/formula-form.sh is the one definition of how a formula installs.
# The three workflows that branch on it call the script and restate nothing.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  SCRIPT="${REPO_ROOT}/scripts/formula-form.sh"
  WORK="${BATS_TEST_TMPDIR}"
}

@test "a formula whose url lines name release archives is prebuilt" {
  cat >"${WORK}/prebuilt.rb" <<'RUBY'
class Prebuilt < Formula
  on_macos do
    on_arm do
      url "https://github.com/owner/repo/releases/download/v1.2.3/repo-aarch64-apple-darwin.tar.gz"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end
end
RUBY
  run "${SCRIPT}" "${WORK}/prebuilt.rb"
  [ "${status}" -eq 0 ]
  [ "${output}" = "prebuilt" ]
}

@test "a formula that builds its tagged tarball is source" {
  cat >"${WORK}/source.rb" <<'RUBY'
class Source < Formula
  url "https://github.com/owner/repo/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
end
RUBY
  run "${SCRIPT}" "${WORK}/source.rb"
  [ "${status}" -eq 0 ]
  [ "${output}" = "source" ]
}

@test "a bottle root_url that names a release does not make a formula prebuilt" {
  cat >"${WORK}/bottled.rb" <<'RUBY'
class Bottled < Formula
  url "https://github.com/owner/repo/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  bottle do
    root_url "https://github.com/owner/repo/releases/download/v1.2.3"
  end
end
RUBY
  run "${SCRIPT}" "${WORK}/bottled.rb"
  [ "${status}" -eq 0 ]
  [ "${output}" = "source" ]
}

@test "a missing formula file is an error, not an answer" {
  run "${SCRIPT}" "${WORK}/absent.rb"
  [ "${status}" -eq 66 ]
  [[ "${output}" == *"no such formula file"* ]]
}

@test "no argument prints the usage and exits 64" {
  run "${SCRIPT}"
  [ "${status}" -eq 64 ]
  [[ "${output}" == *"usage:"* ]]
}

@test "every formula in the tap gets one of the two answers" {
  for formula in "${REPO_ROOT}"/Formula/*.rb; do
    run "${SCRIPT}" "${formula}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == "prebuilt" || "${output}" == "source" ]]
  done
}

@test "each workflow that branches on the form calls the script" {
  for workflow in tests.yml update-formula.yml; do
    run grep -c 'scripts/formula-form.sh' "${REPO_ROOT}/.github/workflows/${workflow}"
    [ "${status}" -eq 0 ] || {
      echo "${workflow} does not call scripts/formula-form.sh"
      return 1
    }
  done
}
