#!/usr/bin/env bash
# Runs the project's static checks and unit tests.
set -euo pipefail

TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

bash "$TESTS_DIR/shellcheck.sh"
echo
bash "$TESTS_DIR/unit.sh"
