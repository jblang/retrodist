#!/usr/bin/env bash
# Runs ShellCheck over the project, treating host scripts as Bash and the
# sourced guest fragments under autoinst/ as POSIX sh. Host scripts are checked
# strictly; the guest fragments accept a curated set of legacy-compatible
# patterns required to run on very old guest shells.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not found in PATH" >&2
    exit 1
fi

# Bash host scripts: strict.
HOST_SCRIPTS=(retro jump qmp retrolib/*.sh slackware/pkgtool.sh tests/*.sh)

# POSIX guest fragments: run on legacy guest shells, so accept patterns that are
# intentional there (word splitting, expr math, -a/-o tests, $? checks, legacy
# egrep/fgrep, echo -n, ls iteration over controlled package dirs, etc.).
GUEST_SCRIPTS=(autoinst/*.sh autoinst/install/*.sh autoinst/config/*.sh)
GUEST_EXCLUDES=SC1091,SC2034,SC2086,SC2003,SC2166,SC2181,SC2162,SC2129,SC2196,SC2197,SC2153,SC2030,SC2031,SC3043,SC2045,SC3037

status=0

echo "ShellCheck: host scripts (bash, strict)"
# shellcheck disable=SC2086
shellcheck -s bash "${HOST_SCRIPTS[@]}" || status=1

echo "ShellCheck: guest fragments (sh, legacy-compatible)"
shellcheck -s sh -e "$GUEST_EXCLUDES" "${GUEST_SCRIPTS[@]}" || status=1

if [ "$status" -eq 0 ]; then
    echo "ShellCheck passed."
fi
exit "$status"
