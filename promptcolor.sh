#!/bin/bash
#
# FILE: promptcolor.sh
#
# ABSTRACT: Show prompt color combinations
#
# AUTHOR: Ralf Schandl
#

fgMin=30
fgMax=38

for ((i = fgMin ; i <= fgMax ; i++ )) ; do
    for ((j = fgMin ; j <= fgMax ; j++ )) ; do
    echo "$i:$j: [01;${i}m(0)user@host[00m:[01;${j}m/home/user[00m"
    done
    echo ""
done

