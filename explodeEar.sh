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
    local dirname=$(dirname "$fqFile")
    local file=$(basename "$fqFile")
    local exploddir=$(echo "$file" | sed "s/\.[^\.]*$//")

    cd "$dirname" || exit 1
    unzip -d "$exploddir" "$file" >/dev/null || exit 1
    local fn
    for fn in $(find "$exploddir" -type f  -name \*.ear -o -name \*.jar -o -name \*.war); do
	explode "$fn"
    done

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
exploddir=$(echo "$file" | sed "s/\.[^\.]*$//")

echo "Exploding $fqFile"
unzip -d "$exploddir" "$fqFile" >/dev/null || exit 1
for fn in $(find $exploddir -type f  -name \*.ear -o -name \*.jar -o -name \*.war); do
    explode "$fn"
done

