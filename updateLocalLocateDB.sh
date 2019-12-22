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

# update locate db
/usr/bin/updatedb -l 0 -o "${LOCATEDB}" -U "${HOME}" -n .svn -n .metadata -n .gvfs

