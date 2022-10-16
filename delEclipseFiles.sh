#!/bin/bash
#
# FILE: delEclipseFiles.sh
#
# ABSTRACT: delete Eclipse administrative files and directories
#
# AUTHOR: Ralf Schandl
#

script_name="$(basename "$0")"

set -e

# files to delete
DEL_FILES=( .project .classpath .checkstyle .factorypath )

# directories to delete
DEL_DIRS=( .settings .apt_generated )

# directories to ignore while searching for files to delete
IGN_DIRS=( .metadata .eclipse .svn .git CVS )

show_help()
{
    echo "Deletes Eclipse administrative files and directories from given dir."
    echo ""
    echo "Usage: $script_name [-Xf] DIR..."
    echo "   -X: delete the files. Without this option, just list Eclipse "
    echo "       administrative files."
    echo "   -f: start deleting even when given dir is not a Eclipe project"
    echo "   DIR... directories to search for files/dirs to delete. Must contain"
    echo "          \".project\" (except '-f' was given)"
    echo ""
    echo "To be deleted:"
    printf '%s, ' "${DEL_FILES[@]}"
    printf '%s/, ' "${DEL_DIRS[@]}"
    echo ""
}

execute=""
force=""
if ! eval "$(parseargs -n "$scriptname" -hio "X#execute,f#force" -- "$@")"; then
    exit 1
fi


PATHS=( "$@" )
if [ ${#PATHS[@]} -eq 0 ]; then
    show_help
    exit 1
fi

delFiles=()
for file in "${DEL_FILES[@]}"; do
    if [ ${#delFiles[@]} -gt 0 ]; then
        delFiles+=(-o)
    fi
    delFiles+=(-name)
    delFiles+=("$file")
done

delDirs=()
for dir in "${DEL_DIRS[@]}"; do
    if [ ${#delDirs[@]} -gt 0 ]; then
        delDirs+=(-o)
    fi
    delDirs+=(-name)
    delDirs+=("$dir")
done

ignDirs=()
for dir in "${IGN_DIRS[@]}"; do
    if [ ${#ignDirs[@]} -gt 0 ]; then
        ignDirs+=(-o)
    fi
    ignDirs+=(-name)
    ignDirs+=("$dir")
done

if [ -n "$execute" ]; then
    fileDelParam=( "-exec" "rm" "{}" ";" )
    dirDelParam=( "-exec" "rm" "-rf" "{}" ";" )
else
    fileDelParam=()
    dirDelParam=()
fi

if [ -z "$force" ]; then
    for d in "${PATHS[@]}"; do
        if [ ! -e "$d/.project" ]; then
            echo >&2 "Not a Eclipse project dir: $d"
            exit 1
        fi
    done
fi

#set -x
find "${PATHS[@]}" \( -type d \( "${ignDirs[@]}" \) -prune \) -o \( -type f \( "${delFiles[@]}" \) -print "${fileDelParam[@]}" \) -o \( -type d \( "${delDirs[@]}" \) -print -prune "${dirDelParam[@]}" \)

if [ -z "$execute" ]; then
    echo
    echo "Use option '-X' to really delete the listed files and directories."
    echo
fi

