#!/usr/bin/env bats
# Each prebuilt formula declares the macOS 15 minimum its release archives are
# built for. The declaration sits inside `on_macos`: at the top level the
# requirement also applies on Linux, where it is never met and Homebrew
# refuses the install.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "each prebuilt formula declares the macOS 15 minimum inside on_macos" {
  local formula count=0
  for formula in "${REPO_ROOT}"/Formula/*.rb; do
    [[ "$("${REPO_ROOT}/scripts/formula-form.sh" "${formula}")" == prebuilt ]] || continue
    count=$((count + 1))
    awk '
      /^  on_macos do$/ { inside = 1; next }
      inside && /^  end$/ { inside = 0 }
      inside && /^    depends_on macos: :sequoia$/ { found = 1 }
      END { exit !found }
    ' "${formula}" || {
      echo "${formula##*/} has no \`depends_on macos: :sequoia\` inside on_macos"
      return 1
    }
  done
  [ "${count}" -gt 0 ]
}

@test "no formula declares a macOS requirement outside on_macos" {
  run grep -nE '^  depends_on (macos|maximum_macos):' "${REPO_ROOT}"/Formula/*.rb
  [ "${status}" -eq 1 ]
}
