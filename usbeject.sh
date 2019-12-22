#!/bin/bash
#
# FILE: usbeject.sh
#
# ABSTRACT: Safely eject usb storage devices
#
# Can't handle USB devices with multiple mounted file systems.
# Don't know how this behaves if a file system is encrypted
#
# AUTHOR: Ralf Schandl
#

#
# Find usb-devices that are mounted. Then show selection list to the user.
# Sets the global variable mount_point to the device of the selected mounted
# drive.
#
select_dir()
{
    # Array containing strings of format:
    # <device> (<vendor and model info>)
    # device: e.g.: /dev/sdc
    # vendor and model info: e.g.: Lenovo - USB Stick
    devs=()
    for x in $(ls /dev/disk/by-id/* 2>/dev/null); do
        devInfo=$(udevadm info --name="$x" --query=all)
        if echo "$devInfo" | grep "ID_PATH=.*-usb-" >/dev/null 2>&1; then
            vendor=$(echo "$devInfo" | grep "^E: ID_VENDOR=" | cut -d= -f2 | sed "s/  *$//;s/_/ /g")
            model=$(echo "$devInfo" | grep "^E: ID_MODEL=" | cut -d= -f2 | sed "s/  *$//;s/_/ /g")
            size=$(echo "$devInfo" | grep "^E: UDISKS_PARTITION_SIZE=" | cut -d= -f2 | sed "s/  *$//;s/_/ /g")
            if [[ -n "$size" ]]; then
                # 1073741824=1024*1024*1024
                size=$(echo "scale=5;$size/1073741824;last+0.05;scale=1;last/1"|bc|tail -n1)
                size="$size GB"
            else
                size='size unkown'
            fi

            devinfo=$(readlink -f "$x")
            devinfo="$devinfo ($vendor - $model - $size)"
            devs+=( "$devinfo" )
        fi
    done

    # Array containing strings of format:
    # <mount point> [label] (<vendor and model info>)
    # mount point: e.g.: /media/LENOVO
    # label (optional): e.g.: LENOVO
    # vendor and model info: e.g.: Lenovo - USB Flash Drive - 7.4 GB
    mounted=()
    for d in "${devs[@]}"; do
        echo "$d"
        device=$(echo "$d" | sed "s/ (.*$//")
        mi=$(mount -l | grep "$device ")
        [[ -z "$mi" ]] && continue
        dir=$(echo "$mi" | sed "s/^[^ ]* on //;s/ type.*$//")
        label=$(echo "$mi" | sed "s/^.*\[/[/")
        [[ "$label" == "$mi" ]] && label=""
        devinfo=$(echo "$d" | sed "s/^[^ ]* (/(/")
        mounted+=("$dir $label $devinfo")
    done

    if [[ ${#mounted[@]} -eq 0 ]]; then
        echo >&2 "No mounted usb device found"
        exit 0
    fi

    select s in "${mounted[@]}"; do
        mount_point=$(echo "$s" | sed "s/ [\[(].*$//")
        break
    done
}

#
# Prints the mount point of the given file system
#
get_mount_point()
{
    fs="$1"
    mount | grep "^$fs on " | sed "s%^$fs on %%;s% type .*$%%"
}

#
# Unmounts a file system. If this fails tries to detect the processes using
# that file system ("device is busy" is probably the most common reason for
# a umount failure").
# Exits if umount fails
#
unmount_fs()
{
    echo "Unmounting $mounted_fs..."
    #udisks --unmount $mounted_fs
    udisksctl unmount -b "$mounted_fs"
    mount | grep "^$mounted_fs" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        local dir="$(get_mount_point "$mounted_fs")"
        if fuser -m "$dir" >/dev/null 2>&1; then
            echo "Processes using $dir:"
            printf "    Usage  PID     Command\n"
            printf "    -----  ------  -------------\n"

            for ln in $(fuser -vm "$dir" 2>&1 | tail -n +3 | sed "s/  */:/g;s/^://"); do
                pid=$(echo "$ln" | cut -d: -f2)
                cmd=$(ps -p $pid -o args=)
                use=$(echo "$ln" | cut -d: -f3)
                # only print if prozess still exists
                [ -n "$cmd" ] && printf "    %5s  %6d  %s\n" "$use" "$pid"  "$cmd"
            done
        fi
        exit 1
    fi
}

#
# First unmounts the file systems of a device and then resumes it (Power off).
# First parameter: the device itself
# Following parameters: devices of file systems
#
remove_device()
{
    device=$1
    shift

    for fs in "$@"; do
        unmount_fs "$fs"
    done

    echo "Detaching $device..."
    #udisks --detach $device
    udisksctl power-off -b "$device"
    [[ $? -eq 0 ]] && echo OK || echo FAILED
}


if [[ -n $1 ]]; then
    mount_point=$(echo "$1"| sed "s/\/$//")
    mount_point=$(readlink -e "$mount_point")
else
    select_dir
    if [[ -z $mount_point ]]; then
        exit 0
    fi
fi

if [[ ! -e "$mount_point" ]]; then
    echo >&2 "mount point '$1' not found"
    exit 1
fi

mounted_fs=$(mount | grep "on $mount_point " | cut "-d " -f1)
if [ -z "$mounted_fs" ]; then
    echo >&2 "file system not found for $mount_point"
    exit 1
fi


device=$(echo "$mounted_fs" | sed "s/[1-9][0-9]*$//")

remove_device "$device" "$mounted_fs"

