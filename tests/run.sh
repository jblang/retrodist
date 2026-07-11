#!/usr/bin/env bash
# Runs the project's static checks and unit tests.
set -euo pipefail

TESTS_D=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

bash "$TESTS_D/shellcheck.sh"
echo
bash "$TESTS_D/unit.sh"
