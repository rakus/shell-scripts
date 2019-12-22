#!/bin/sh
#
# FILE: manifest.sh
#
# ABSTRACT: Show MANIFEST.MF of jar, war or ear
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

showManifest()
{
    unzip -qc "$1" META-INF/MANIFEST.MF 2>/dev/null
    rc=$?
    if [ $rc -eq 11 ]; then
        # maybe not written all upper case .. try it
        MfName=$(zipinfo -1 "$1" | grep -i "^META-INF/MANIFEST.MF$" | head -1)
        if [ -n "$MfName" ]; then
            unzip -qc "$1" "$MfName" 2>/dev/null
        else
            echo >&2 "$1: No manifest found"
        fi
    elif [ $rc -ne 0 ]; then
        echo >&2 "$1: Unpacking failed"
    fi
}

if [ $# -eq 0 ]; then
    echo "Shows MANIFEST.MF from jar file(s)."
    echo "Usage $script_name <jarfile> ..."
    exit 1
fi


for fn in "$@"; do
    [ $# != 1 ] && echo "" && echo "===>> $fn"
    if [ -r "$fn" ]; then
        showManifest "$fn"
    else
        echo >&2 "$fn: Not found or not readable"
    fi
done

