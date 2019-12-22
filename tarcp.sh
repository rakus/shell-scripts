#!/bin/bash
#
# FILE: tarcp.sh
#
# ABSTRACT: Copy dir with 'tar -cf - | tar -xf -'
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

if [[ $# -ne 2 ]]; then
    echo >&2 "Need 2 parameter"
    echo >&2 "$script_name <src-dir> <target-dir>"
    exit 1
fi

SOURCE=$1
TARGET=$2

if [[ ! -d "$SOURCE" ]]; then
    echo >&2 "Source directory not found: $SOURCE"
    exit 1
fi

if [[ ! -d "$TARGET" ]]; then
    echo >&2 "Target directory not found: $TARGET"
    exit 1
fi

set -e

BASEDIR=$(dirname "$SOURCE")
BASENAME=$(basename "$SOURCE")

READERR_FILE="$TARGET/c.err"
WRITEERR_FILE="$TARGET/x.err"

if type pv >/dev/null 2>&1; then
    (cd "$BASEDIR" && tar -cf - "$BASENAME") 2>"$READERR_FILE" | pv -trab -B 500M | (cd "$TARGET" && tar -xf -) 2>"$WRITEERR_FILE"
else
    echo >&2 "pv not found -- no progress information"
    (cd "$BASEDIR" && tar -cf - "$BASENAME") 2>"$READERR_FILE" | (cd "$TARGET" && tar -xf -) 2>"$WRITEERR_FILE"
fi

ok=2

if [[ -s "$READERR_FILE" ]]; then
    echo "====[ Read Errors ]===="
    cat "$READERR_FILE"
else
    echo "NO read errors"
    ok=$((ok-1))
    rm "$READERR_FILE"
fi

if [[ -s "$WRITEERR_FILE" ]]; then
    echo "====[ Write Errors ]===="
    cat "$WRITEERR_FILE"
else
    echo "NO write errors"
    ok=$((ok-1))
    rm "$WRITEERR_FILE"
fi

if [ "$ok" = "0" ]; then
    echo "OK"
else
    echo "ERROR"
fi

