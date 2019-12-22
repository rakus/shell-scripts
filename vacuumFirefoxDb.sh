#!/bin/sh
#
# FILE: vacuumFirefoxDb.sh
#
# ABSTRACT: sqlite firefox databases
#
# AUTHOR: Ralf Schandl
#

FF_DIR=$HOME/.mozilla/firefox

cd "$FF_DIR" || exit 1

find . -name \*.sqlite |
while read -r fn; do
    if ! fuser "$fn" >/dev/null 2>&1; then
        echo "Vacuuming $fn"
        oldSize=$(stat -c %s "$fn")
        sqlite3 "$fn" VACUUM
        newSize=$(stat -c %s "$fn")
        diff=$(( newSize -  oldSize))
        echo "      $oldSize -> $newSize ($diff)"
    else
        echo "Currently used: $fn"
    fi
done

