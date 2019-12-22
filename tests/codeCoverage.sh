#!/bin/bash
#
# FILE: codeCoverage.sh
#
# ABSTRACT:
#
# For BASH scripts:
#    # collect executed line numbers for code coverage
#    PS4='::${LINENO}+'
#    exec 4>>${script_name}.line.log
#    BASH_XTRACEFD=4
#    set -x
#
# For other shell (not tested):
#    # collect executed line numbers for code coverage
#    PS4='::${LINENO}+'
#    exec 3>&2 2> >(tee -a "${script_name}.line.log" >&2)
#    set -x
#
# AUTHOR: Ralf Schandl
#

grep "^::" $1.line.log | sed "s/^:::*//" | cut -d+ -f1 | grep "^[0-9]" | sort -n | sed "s%$%s/^/XX/%" | uniq > sed.cmd

sed -f sed.cmd ../$1 > $1.tested.sh

#---------[ END OF FILE codeCoverage.sh ]--------------------------------------
