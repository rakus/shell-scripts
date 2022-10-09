#!/bin/sh
#
# FILE: updateLocalLocateDB.sh
#
# ABSTRACT: Update local locatedb
#
# Normally called via crontab. E.g.:
#     # m h  dom mon dow   command
#     13 * * * * ${HOME}/bin/updateLocalLocateDB.sh
#
# AUTHOR: Ralf Schandl
#

LOCATEDB=${HOME}/.locatedb

# also omit this directories (space-separated)
PRUNE_NAMES=".svn .metadata .gvfs .git __pycache__"

#---------[ MAIN ]-------------------------------------------------------------

prune_options=()
prune_options+=(-n "$PRUNE_NAMES")

# update locate db
updatedb -l 0 -o "${LOCATEDB}" -U "${HOME}" "${prune_options[@]}"

