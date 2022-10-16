#!/bin/bash
# Requires V4 or later
#
# FILE: lsColors.sh
#
# ABSTRACT: Shows colors used by ls command
#
# This script interpretes the value of the environment variable LS_COLORS.
#
# Default colors are determined from 'dircolors -p'.
#
# AUTHOR: Ralf Schandl
#

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo >&2 "ERROR: This script needs bash version 4 or later."
    exit 255
fi

# Color used for error messages
ERRCOLOR="01;33;41"

# maps colors to extensions
# key: color code
# value: file extensions (separated by ' ')
declare -A ext_map

# maps file type/mode code to color
# also holds default control codes
# key: file type/mode code (abbreviations from LS_COLORS)
# value: color code
declare -A ft_map

# maps abbreviations in LS_COLORS to user-readable text
# key: file type/mode code (abbreviations from LS_COLORS)
# value: human readable description
declare -A ft_desc
ft_desc=(
["no"]="Normal (non-filename) text"
["fi"]="Regular file"
["ex"]="Executable file"
["di"]="Directory"
["tw"]="Directory Other-Writeable with Sticky Bit (+t,o+w)"
["ow"]="Directory Other-Writeable (o+w)"
["ln"]="Symbolic link"
["or"]="Symbolic Link to not existing/accessible file (orphaned)"
["mh"]="File with multiple hard links"
["mi"]="Missing file of a orphaned symbolic link"
["pi"]="FIFO/Pipe"
["so"]="Socket"
["do"]="Door (Solaris 2.5 and later)"
["bd"]="Block device special file"
["cd"]="Character device special file"
["su"]="SETUID (u+s)"
["sg"]="SETGID (g+s)"
["ca"]="File with CAPABILITY" # Whatever this is ...
["st"]="Sticky Bit set (+t)"
)

# maps variable names used in `dircolor -p` to abbreviations in LS_COLORS
# key: variable names
# value: file type/mode code (abbreviations from LS_COLORS)
declare -A names_abbr
names_abbr=(
["NORMAL"]="no"
["FILE"]="fi"
["EXEC"]="ex"
["DIR"]="di"
["STICKY_OTHER_WRITABLE"]="tw"
["OTHER_WRITABLE"]="ow"
["LINK"]="ln"
["ORPHAN"]="or"
["MULTIHARDLINK"]="mh"
["MISSING"]="mi"
["FIFO"]="pi"
["SOCK"]="so"
["DOOR"]="do"
["BLK"]="bd"
["CHR"]="cd"
["SETUID"]="su"
["SETGID"]="sg"
["CAPABILITY"]="ca"
["STICKY"]="st"
)

# maps abbreviations in LS_COLORS to variable names used in `dircolor -p`
# automatically generated from names_abbr
# key: file type/mode code (abbreviations from LS_COLORS)
# value: variable names
#declare -A abbr_names
#for n in "${!names_abbr[@]}"; do
#    abbr_names[${names_abbr[$n]}]="$n"
#done

# Create default ls-color from output of 'dircolors -p'
createDefault()
{
    typeset -a parts
    oldIFS="$IFS"
    IFS=$'\n'
    for ln in $(dircolors  -p  | grep  -v "^\(TERM\| *#\)" | sed "s/ *#.*$//"); do
        IFS=' ' parts=( $ln )
        local k=${parts[0]}
        local c=${parts[1]}

        [ "$k" = "RESET" ] && continue
        if [[ $k != .* ]]; then
            local abbr=${names_abbr[$k]}
            if [ -z "$abbr" ]; then
                echo >&2 "ERROR parsing output of 'dircolor -p': Unknown: $k"
                exit 1
            fi
            echo -n "$abbr=$c:"
        fi
    done
    IFS="$oldIFS"
}

# check that we can parse the output of 'dircolors -p'
createDefault > /dev/null

# Display file types in this order
display_order="no fi ex di tw ow ln or mi mh pi so do bd cd su sg ca st"

# ls default colors extracted from source of /bin/ls (coreutils 7.4)
# Entry separator is ':'
# Not set by default: no, fi, mi, or
#ls_default_colors="di=01;34:ln=01;36:pi=33:so=01;35:bd=01;33:cd=01;33:ex=01;32:do=01;35:su=37;41:sg=30;43:st=37;44:ow=34;42:tw=30;42:ca=30;41"

# ls default colors from 'dircolors -p'
ls_default_colors=$(createDefault)


# Default control codes from source of /bin/ls (coreutils 7.4)
# Entry separator is ':'
# lc: left of color sequence
# rc: right of color sequence
# rs: sequence to reset color
# cl: clear to end of line (not used in this script)
# ec: end of color sequence string -- not set by default
#     would replace $lc$rs$rc
ls_ctrl_codes="lc=\033[:rc=m:rs=0:cl=\033[K:"

# concat defaults and actual LS_COLORS
# As we go left to right, definitions in LS_COLORS will
# overwrite earlier definitions.
lsc="${ls_ctrl_codes}${ls_default_colors}${LS_COLORS}"

warnings=0
orgIFS=$IFS
IFS=":"
for l in $lsc; do
    if [ -z "$l" ]; then
        # ignore empty entry
        continue
    fi
    # extract color code
    #C=$(echo $l | sed "s/^.*=//")
    C=${l#*=}
    if [ -z "$C" ]; then
        # ignore entry without color code
        echo "Warning: Entry without color sequence: '$l' -- ignored" >&2
        (( warnings = warnings + 1 ))
        continue
    fi
    # extract type or file extension
    #T=$(echo $l | sed "s/=.*$//")
    T=${l%%=*}
    if [ -z "$T" ]; then
        # ignore entry without name
        echo "Warning: Entry without name: '$l' -- ignored" >&2
        (( warnings = warnings + 1 ))
        continue
    fi
    if [ "$T" = "$C" ]; then
        # ignore entry without a '='
        echo "Warning: Invalid entry: '$l' -- ignored" >&2
        (( warnings = warnings + 1 ))
        continue
    fi

    # put into right map
    if [[ $T =~ ^\*.*$ ]]; then
        #echo ">>>$T<<<"
        # its a file extension
        if ! echo "${ext_map[$C]}" | grep "$T" >/dev/null 2>&1; then
            ext_map[$C]="${ext_map[$C]}$T "
        fi
    else
        # its a file type/mode
        ft_map[$T]="$C"
    fi
done
IFS=$orgIFS

[ $warnings -gt 0 ] && echo ""

# handle some default replacements

# if orphaned is not set it defaults to ln (if that is set)
if [ -z "${ft_map[or]}" ]; then
    if [ -n "${ft_map[ln]}" ]; then
        ft_map[or]=${ft_map[ln]}
    fi
fi

# if missing is not set or is set to '00' (aka 'none') it defaults to orphaned
# (if that is set)
if [ -z "${ft_map[mi]}" ] || [ "${ft_map[mi]}" = "00" ]; then
    if [ -n "${ft_map[or]}" ]; then
        ft_map[mi]=${ft_map[or]}
    fi
fi

# Extract control codes and delete entries afterwards
# At least lc, rc, rs and cl are always set (see ls_ctrl_codes above)
LC=${ft_map[lc]}
RC=${ft_map[rc]}
RS=${ft_map[rs]}
# shellcheck disable=SC2034 # variable is currently not used
CEOL=${ft_map[cl]}
RST=${ft_map[ec]}
unset "ft_map[lc]"
unset "ft_map[rc]"
unset "ft_map[rs]"
unset "ft_map[cl]"
unset "ft_map[ec]"

# if "reset color string" not set, build it from other control codes
if [ -z "$RST" ]; then
    RST=${LC}${RS}${RC}
fi

symlink_uses_target_color=false

# show file types in predefined order
# remove from ft_map, so it will not be shown again below
for k in $display_order; do
    T=${ft_desc[$k]}
    C=${ft_map[$k]}
    unset "ft_map[$k]"


    # color for symlink can be 'target', means symlink uses same color as
    # linked target
    if [ "$k" = "ln" ] && [ "$C" = "target" ]; then
        symlink_uses_target_color=true
        continue
    else
        _C="${LC}${C}${RC}example${RST}"
    fi

    if [ -z "$T" ]; then
        T="${LC}${ERRCOLOR}${RC}ERROR: Unknown Type '$k'${RST}"
    fi

    echo -e "$_C [$k] $T"
    #printf "%-57s %b\n" "$T" "$_C"
done

# show remaining file type entries in random order
# This is the safty net for possible new file type/mode codes.
# 1) ft_map should be empty by now
# 2) if it is not empty, all entries should be "Unknown type"
# If something is displayed here, ft_desc and display_order should be adjusted
if [ ${#ft_map[@]} -gt 0 ]; then
    echo >&2 ""
    echo >&2 -e "Warning: Unknown filetypes found:"
    for k in "${!ft_map[@]}"; do
        T=${ft_desc[$k]}
        C=${ft_map[$k]}
        if [ -n "$T" ]; then

            echo -e "${LC}${C}${RC}example${RST}  $T"
        else
            echo -e "${LC}${C}${RC}example${RST}  ${LC}${ERRCOLOR}${RC}ERROR: Unknown Type '$k'${RST}"
        fi
    done
fi

if [ $symlink_uses_target_color = true ]; then
    echo ""
    echo "Note: Symbolic link uses color of link target"
fi

echo ""
echo "Colors by file extension:"
for k in "${!ext_map[@]}"; do
    echo -e "${LC}${k}${RC}${ext_map[$k]}${RST} "
done

