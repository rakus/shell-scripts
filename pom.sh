#!/bin/sh
#
# FILE: pom.sh
#
# ABSTRACT: Show pom.xml of jar, war or ear
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

showPom()
{
    unzip -qc "$1" "META-INF/maven/*/*/pom.xml" 2>/dev/null
    rc=$?
    if [ $rc -eq 11 ]; then
        # maybe not written all upper case .. try it
        MfName=$(zipinfo -1 "$1" | grep -i "^META-INF/maven/.*/pom.xml$" | head -1)
        if [ -n "$MfName" ]; then
            unzip -qc "$1" "$MfName" 2>/dev/null
        else
            echo >&2 "$1: No pom.xml found"
        fi
    elif [ $rc -ne 0 ]; then
        echo >&2 "$1: Unpacking failed"
    fi
}

if [ $# -eq 0 ]; then
    echo "Shows pom.xml from jar file."
    echo "Usage $script_name <jarfile> ..."
    exit 1
fi


for fn in "$@"; do
    [ $# != 1 ] && echo "" && echo "===>> $fn"
    if [ -r "$fn" ]; then
        showPom "$fn"
    else
        echo >&2 "$fn: Not found or not readable"
    fi
done

