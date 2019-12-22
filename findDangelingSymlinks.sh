#!/bin/bash
#
# FILE: findDangelingSymlinks.sh
#
# ABSTRACT:
#
# AUTHOR: Ralf Schandl
#

if [[ $# -gt 0 ]]; then
    startDir="$1"
else
    startDir="."
fi

find "$startDir" -type l -exec test ! -e {} \; -exec ls --color -l {} \;

