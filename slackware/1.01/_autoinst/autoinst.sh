#!/bin/sh
# Automatic installation for retro distros
AUTOINST=$( cd "$( dirname "$0" )" > /dev/null 2>&1 && pwd )

echo "# automatic installation"

# run installation scripts
for INSTFILE in $AUTOINST/install.d/[0-9]*.sh; do
    . "$INSTFILE"
done