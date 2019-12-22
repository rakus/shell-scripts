#!/bin/sh
#
# FILE: pingcheck.sh
#
# ABSTRACT: Checks via ping if host is available
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

timeout=30
if [ $# -eq 1 ]; then
    adr=$1
elif [ $# -eq 2 ]; then
    adr=$1
    timeout=$2

    if [ ! "$timeout" -eq "$timeout" ] 2>/dev/null ; then
        echo >&2 "Timeout value must be numeric and greater 0"
        exit 1
    fi
else
    echo >&2 "Usage: $script_name host [timeout between retries]"
    exit 1
fi

while true; do

    printf "."
    if ping -c 1 "$adr" >/dev/null; then
        zenity --title="PingCheck $adr" --info --text="Host $adr reached" 2>/dev/null &
        #xmessage "Host $RemoteHost reached"
        echo
        exit 0
    fi

    sleep "$timeout"
done

