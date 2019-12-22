#!/bin/sh
#
# FILE: usbpower.sh
#
# ABSTRACT: Print the electric current the USB devices receive from the host
#
# AUTHOR: Ralf Schandl
#

lsusb | grep -v "root hub" |
while read -r l; do
    devAddr=$(echo "$l" | sed "s/^Bus //;s/ Device /:/;s/: ID.*$//")
    #devId=$(echo "$l" | cut "-d " -f 6)
    devName=$(echo "$l" | cut "-d " -f 7-)

    lsusbV=$(lsusb -v -s "$devAddr" 2>/dev/null)
    if [ $? -eq 0 ]; then
        maxPower=$(echo "$lsusbV" | grep MaxPower | sed "s/^[ \t]*MaxPower[ \t]*//;s/mA$//" | sort -rn | head -1)
        #maxPower=$(echo "$lsusbV" | grep MaxPower | head -1 | sed "s/^[^0-9]*//;s/mA$//")
        if [ -n "$maxPower" ]; then
            printf "%s: %-30s %3dmA\n" "$devAddr" "$devName" "$maxPower"
        else
            printf "%s: %-30s ???mA\n" "$devAddr" "$devName"
        fi
    else
        printf "%s: %-30s Error reading details\n" "$devAddr" "$devName"
    fi


done

