#!/bin/bash
#
# FILE: drop-fs-chaches.sh
#
# ABSTRACT: 
#
# AUTHOR: Ralf Schandl
#
# CREATED: 2017-03-07
#

script_dir=$(cd "$(dirname $0)" 2>/dev/null; pwd)
script_name="$(basename "$0")"
script_file="$script_dir/$script_name"

if [[ $(id -un) != "root" ]]; then
    echo "Need root - sudoing..."
    exec sudo "$0" "$@"
fi

echo "Dropping file system caches..."
sync; sync; echo 3 > /proc/sys/vm/drop_caches

#---------[ END OF FILE drop-fs-chaches.sh ]-----------------------------------
