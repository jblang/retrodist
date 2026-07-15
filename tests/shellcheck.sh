#!/usr/bin/env bash
# Runs ShellCheck over the bootstrap, custom extraction hooks, test launchers,
# and portable guest fragments.
set -euo pipefail

REPO_D=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_D"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not found in PATH" >&2
    exit 1
fi

# The bootstrap, extraction hooks, and test launchers use Bash strictly.
HOST_SCRIPTS=(retro-prereq tests/*.sh)
while IFS= read -r file; do
    HOST_SCRIPTS+=("$file")
done < <(find debian redhat slackware -name extract.sh -not -path '*/qemu.d/*' -not -path '*/download.d/*' -print)

# POSIX guest fragments: run on legacy guest shells, so accept patterns that are
# intentional there (word splitting, expr math, -a/-o tests, $? checks, legacy
# egrep/fgrep, echo -n, ls iteration over controlled package dirs, etc.).
GUESTLIB_SCRIPTS=(guestlib/*.sh guestlib/config/*.sh guestlib/deb091/*.sh)
while IFS= read -r file; do
    GUESTLIB_SCRIPTS+=("$file")
done < <(find debian redhat slackware -name postinst.sh -not -path '*/qemu.d/*' -not -path '*/download.d/*' -print)
GUEST_EXCLUDES=SC1091,SC2034,SC2086,SC2003,SC2166,SC2181,SC2162,SC2129,SC2196,SC2197,SC2153,SC2030,SC2031,SC3043,SC2045,SC3037

status=0

echo "ShellCheck: host scripts (bash, strict)"
# shellcheck disable=SC2086
shellcheck -s bash "${HOST_SCRIPTS[@]}" || status=1

echo "ShellCheck: guest fragments (sh, legacy-compatible)"
shellcheck -s sh -e "$GUEST_EXCLUDES" "${GUESTLIB_SCRIPTS[@]}" || status=1

if [ "$status" -eq 0 ]; then
    echo "ShellCheck passed."
fi
exit "$status"
