#!/usr/bin/env bash
# Prints how a formula installs, on one line:
#
#   prebuilt   its `url` lines name the archives its release publishes
#              (`releases/download/`), and `install` copies the binary out
#   source     it builds the tagged source tarball
#
# A prebuilt formula gets no bottle: a bottle of it is the same binary
# packed again. update-formula.yml, tests.yml and publish.yml each branch on
# this answer, and tests/formula-form.bats fails when one of them stops
# calling this script.
#
# Usage:
#   scripts/formula-form.sh Formula/<name>.rb

set -euo pipefail

if [[ $# -ne 1 ]]
then
  echo "usage: ${0##*/} <formula file>" >&2
  exit 64
fi

formula_file="$1"
if [[ ! -f ${formula_file} ]]
then
  echo "error: no such formula file: ${formula_file}" >&2
  exit 66
fi

if grep -qE '^ *url "https://github\.com/[^/]+/[^/]+/releases/download/' "${formula_file}"
then
  echo "prebuilt"
else
  echo "source"
fi
