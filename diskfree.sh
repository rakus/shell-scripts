#!/bin/bash
#
# FILE: diskfree.sh
#
# ABSTRACT: Nice display of free disk space
#
# Stolen this from somewhere and reworked it.
#
# AUTHOR: Ralf Schandl
#

script_name="$(basename "$0")"

# limit in percent to use warn_color
warn_limit=70
# limit in percent to use severe_color
severe_limit=90

ok_color=$(tput bold;tput setaf 2)
warn_color=$(tput bold;tput setaf 3)
severe_color=$(tput bold;tput setaf 1)
color_off=$(tput sgr0)

term_cols=$(tput cols)
if [ "$term_cols" -gt "101" ]; then
    term_cols=101
fi

printDiskUsage()
{
    read -r device mount_point size used free percent <<< "$(df -h --output=source,target,size,used,avail,pcent "$1" | tail -n1 2> /dev/null)"

    percent="${percent%\%}"

    (( used_bar= (percent * (term_cols - 3))/100 ))
    (( free_bar = term_cols - used_bar - 3 ))

    if [ "$percent" -gt "$severe_limit" ]; then
        color=$severe_color
    elif [ "$percent" -gt "$warn_limit" ]; then
        color=$warn_color
    else
        color=$ok_color
    fi

    echo "Mount point: $mount_point"
    echo "File system: $device"
    printf "Total size: %s | Used space: %s | Free space: %s | Used space percent: %d%%\n" "$size" "$used" "${color}$free${color_off}" "$percent"

    echo -ne "[${color}"
    [ $used_bar -gt 0 ] && printf '#%.0s' $(seq 1 $used_bar)
    echo -ne "${color_off}"

    [ $free_bar -gt 0 ] && printf '=%.0s' $(seq 1 $free_bar)
    echo "]${color_off}"
    echo
}

#---------[ MAIN ]-------------------------------------------------------------
all=""
while getopts "a" o "$@"; do
    case $o in
        a) all="true"
            ;;
        *)
            echo >&2 "Usage: $script_name <device or directory>"
            echo >&2 "Usage: $script_name [-a]"
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

echo
if [ $# != 0 ]; then
    for fs in "$@"; do
        printDiskUsage "$fs"
    done
else
    while read -r mpoint fstype; do
        case "$fstype" in
            ext*|vfat)
                printDiskUsage "$mpoint"
                ;;
            tmpfs)
                if [ -n "$all" ]; then
                    printDiskUsage "$mpoint"
                fi
                ;;
            *) : ;;
        esac
    done <<< "$(df --output=target,fstype  | tail -n +2)"
fi
