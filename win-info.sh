#!/bin/bash
#
# FILE: win-info.sh
#
# ABSTRACT: Print XWindow info of clicked window
#
# AUTHOR: Ralf Schandl
#

info=$(xwininfo | grep "^xwininfo" | grep -v "Please")

#echo $info

winid=$(echo "$info" | cut "-d " -f 4)
winname=$(echo "$info" | cut "-d " -f 5-)

#echo "ID:   $winid"
#echo "Name: $winname"

pid=$(xprop -id "$winid" _NET_WM_PID | cut "-d " -f 3 )
wmclass=$(xprop -id "$winid" WM_CLASS | cut "-d " -f 3- )

#echo "PID: $pid"

if [[ "$pid" =~ ^[0-9] ]]; then
    p_info=$(ps u -ww -p "$pid")
    if [ $? -ne 0 ]; then
        p_info="Process $pid does not exist anymore. Window maybe opened by child process"
    fi
else
    pid="unknown"
    p_info=""
fi

output="
Win ID:     $winid
Win Name:   $winname
WM Class:   $wmclass
Process ID: $pid

$p_info

"


if [[ -t 0 || -t 1 ]]; then
    # we are running on a terminal
    echo "$output"
else
    xmessage -title "X Window Info" "$output"
fi


#if [[ "$1" == "-X" ]]; then
#    #zenity --title="X Window Info" --info --text="$output"
#    xmessage -title "X Window Info" "$output"
#    #echo "$output" | zenity --title TEST --text-info
#else
#    echo "$output"
#fi

