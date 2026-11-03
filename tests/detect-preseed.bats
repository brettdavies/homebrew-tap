#!/usr/bin/env bats
# tests.yml's detect job skips a formula pre-seeded at v0.0.0, whose release
# does not exist yet, in either formula form. These cases run the regex the
# workflow carries, read from its `const preseedRegex = ...;` line.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  REGEX="$(sed -nE 's/^ *const preseedRegex = (.*);$/\1/p' "${REPO_ROOT}/.github/workflows/tests.yml")"
  if [[ -z ${REGEX} ]]; then
    echo "tests.yml has no one-line \`const preseedRegex = ...;\`" >&2
    return 1
  fi
}

is_preseed() {
  node -e "process.exit(${REGEX}.test(process.argv[1]) ? 0 : 1)" "$1"
}

@test "a source formula pre-seeded at v0.0.0 is skipped" {
  run is_preseed '  url "https://github.com/owner/repo/archive/refs/tags/v0.0.0.tar.gz"'
  [ "${status}" -eq 0 ]
}

@test "a prebuilt formula pre-seeded at v0.0.0 is skipped" {
  run is_preseed '      url "https://github.com/owner/repo/releases/download/v0.0.0/repo-aarch64-apple-darwin.tar.gz"'
  [ "${status}" -eq 0 ]
}

@test "a source formula at a real version is tested" {
  run is_preseed '  url "https://github.com/owner/repo/archive/refs/tags/v1.2.3.tar.gz"'
  [ "${status}" -eq 1 ]
}

@test "a prebuilt formula at a real version is tested" {
  run is_preseed '      url "https://github.com/owner/repo/releases/download/v1.2.3/repo-aarch64-apple-darwin.tar.gz"'
  [ "${status}" -eq 1 ]
}

@test "a prebuilt formula at v10.0.0 is tested" {
  run is_preseed '      url "https://github.com/owner/repo/releases/download/v10.0.0/repo-aarch64-apple-darwin.tar.gz"'
  [ "${status}" -eq 1 ]
}
