#!/usr/bin/env bash
# Runs the Python host unit and configuration coverage suite.
set -euo pipefail

REPO_D=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [ -z "${PYTHON:-}" ] && [ -x "$REPO_D/.venv/bin/python" ]; then
    PYTHON=$REPO_D/.venv/bin/python
else
    PYTHON=${PYTHON:-python3}
fi

cd "$REPO_D"
exec "$PYTHON" -m unittest tests.test_python
