#!/bin/sh
#
# FILE: tsfile.sh
#
# ABSTRACT: Creates copy of file with timestamp appended.
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

show_help()
{
    echo "Usage: $script_name [-tm] file ..."
    echo ""
    echo "   -t use last modification time instead of current time"
    echo "   -m move the file instead of copying"
    echo ""
    echo "Copies (or moves) the file(s) by appending the modification timestamp"
    echo ""
    exit 0
}

move=""
modtime=""
cmd=$(parseargs -s sh -ho "m:move#move,t:modtime#modtime" -- "$@")
eval "$cmd" || exit 1

ts=$(date "+%Y-%m-%dT%H.%M.%S")

for fn in "$@"; do
    if [ -e "$fn" ]; then
        fn=$(echo "$fn" | sed "s/\/$//")
        if [ -n "$modtime" ]; then
            modTime=$(stat -c %Y "$fn")
            ts=$(date -d "@${modTime}" "+%Y-%m-%dT%H.%M.%S")
        fi
        echo "$fn  ->  $fn.$ts"
        if [ $move ]; then
            mv "$fn" "$fn.$ts"
        else
            cp -r "$fn" "$fn.$ts"
            touch -r "$fn" "$fn.$ts"
        fi
    else
        echo >&2 "File not found: $fn"
    fi
done

