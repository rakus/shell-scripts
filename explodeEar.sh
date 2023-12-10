#!/bin/bash
#
# FILE: explodeEar.sh
#
# ABSTRACT: extract an ear and all contained war/jar
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

explode()
{
    pushd . >/dev/null

    echo "Exploding $1"
    local fqFile="$1"
    # shellcheck disable=SC2155
    local dirname=$(dirname "$fqFile")
    # shellcheck disable=SC2155
    local file=$(basename "$fqFile")
    # shellcheck disable=SC2155,SC2001
    local exploddir=$(echo "$file" | sed "s/\.[^\.]*$//")

    cd "$dirname" || exit 1
    unzip -d "$exploddir" "$file" >/dev/null || exit 1
    local fn
    for fn in $(find "$exploddir" -type f  -name \*.ear -o -name \*.jar -o -name \*.war); do
	explode "$fn"
    done

    # shellcheck disable=SC2164
    popd >/dev/null
}

#---------[ MAIN ]-------------------------------------------------------------

if [ $# != 1 ]; then
    echo >&2 "Usage: $script_name <ear-file>"
    exit 1
fi

fqFile=$1
if [ ! -r "$fqFile" ]; then
    echo >&2 "File not found or not readable: $fqFile"
    exit 1
fi

file=$(basename "$fqFile")
# shellcheck disable=SC2001
exploddir=$(echo "$file" | sed "s/\.[^\.]*$//")

echo "Exploding $fqFile"
unzip -d "$exploddir" "$fqFile" >/dev/null || exit 1
# shellcheck disable=SC2044
for fn in $(find $exploddir -type f  -name \*.ear -o -name \*.jar -o -name \*.war); do
    explode "$fn"
done

