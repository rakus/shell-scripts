#!/bin/sh
#
# FILE: runtests.sh
#
# ABSTRACT: run all test-*.sh files in this directory
#
# Fails if one of the scripts fail.
#
# AUTHOR: Ralf Schandl
#

script_dir=$(cd "$(dirname $0)" 2>/dev/null; echo "$PWD")
script_name=$(basename $0)

cd "$script_dir"

strt=$(date +%s.%N)
if [ $# = 0 ]; then
    run-parts --exit-on-error --regex="^test-.*\\.sh?\$" .
else
    for name in "$@"; do
        name=$(basename $name .sh)
        if ! ls | egrep "^(test-)?${name}.*\\.sh?\$" >/dev/null 2>&1; then
            echo >&2 "No tests matching ${name} found."
            exit 1
        fi
        run-parts --exit-on-error --regex="^(test-)?${name}.*\\.sh?\$" .
    done
fi
end=$(date +%s.%N)
echo "---------------------"
echo "Duration $(echo "scale=2; ($end - $strt)/1" | bc) seconds"

#---------[ END OF FILE runtests.sh ]------------------------------------------
