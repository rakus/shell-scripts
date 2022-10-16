#!/bin/bash
#
# FILE: validatePath.sh
#
# ABSTRACT:
#
# AUTHOR: Ralf Schandl
#

script_name=$(basename "$0")

show_help()
{
    echo "Validate that the PATH environment variable is correct."
    echo "Checks for none existing directories, duplicate entries and relative paths"
    echo "(starting with '.')."
    echo "Finally it prints code to set the correct PATH. To fix your PATH environment"
    echo "variable use:"
    echo "    eval \$($script_name)"

    echo "To validate and fix any other path-like variable its name can be given with"
    echo "'-n':"
    echo "    eval \$($script_name -n LD_LIBRARY_PATH)"

    echo ""
    echo "If the path is given on the command line, correction code is only printed if"
    echo "also the name of this variable is given (-n/--name)."
    echo ""

    echo "Note that the shell interprets empty path elements (leading, trailing or"
    echo "double ':') as '.'. Empty path elements are replaced with '.' to make that"
    echo "explicit."
    echo ""

    echo ""
    echo "Usage: ${script_name} OPTIONS [-n name [path]]"
    echo "    -c --allow-current   allow current directory ('.')"
    echo "    -r --allow-relative  allow relative paths (not starting with '/')"
    echo "    -q --quiet           don't print warnings"
    echo "       --help            show this help"
    echo "       --version         shows version info"
    echo ""
    echo "    -n --name <name>     Name of the environment variable to export"
    echo "                         If the path is given on the command line export it"
    echo "                         with this name."
    echo "                         If no path is given, get path from the named variable."
    echo "    path                 path to check instead of PATH"
    echo ""
}

allowCurrent=''
allowRelative=''
quiet=''
envName=''
cmd=$(parseargs -s sh -n "${script_name}" -ho "c:allow-current#allowCurrent,r:allow-relative#allowRelative,q:quiet#quiet,n:name=envName" -- "$@")
eval "$cmd" || exit 1


checkpath=
case $# in
    0)  # [ -n "$envName" ] && echo >&2 "WARNING: Option -n/--name ignored"
        if [ -n "$envName" ]; then
            checkpath="${!envName}"
        else
            checkpath="$PATH"
            envName=PATH
        fi
        ;;
    1)  checkpath="$(eval echo "$1")"
        ;;
    *)  echo >&2 "To many arguments"
        exit 1
        ;;
esac

cptmp=$(echo "$checkpath" | sed "s/::/:.:/g;s/^:/.:/;s/:$/:./")
if [ "$cptmp" != "$checkpath" ]; then
    [ -z "$quiet" ] && echo >&2 "# WARNING: fixed empty path elements (replaced with '.')"
    checkpath=$cptmp
fi

IFS_SAVE="$IFS"
IFS=:
elements=""
for p in $checkpath; do
    if [ -d "$p" ]; then
        if echo "$elements" | grep -F ":$p:" >/dev/null; then
            [ -z "$quiet" ] && echo >&2 "# REMOVED: Duplicate path element: \"$p\""
        elif [ "$p" = "." ];then
            if [ -n "$allowCurrent" ]; then
                elements="$elements:$p:"
            else
                [ -z "$quiet" ] && echo >&2 "# REMOVED: Path contains current directory ('.')"
            fi
        elif [ "${p:0:1}" != '/' ]; then
            if [ -n "$allowRelative" ]; then
                [ -z "$quiet" ] && echo >&2 "# OK \"$p\""
                elements="$elements:$p:"
            else
                [ -z "$quiet" ] && echo >&2 "# REMOVED: Path contains relative path: \"$p\""
            fi
        else
            elements="$elements:$p:"
        fi
    elif [ -z "$p" ]; then
        if [ "$allowRelative" == "true" ]; then
            [ -z "$quiet" ] && echo >&2 "# OK \"$p\""
            elements="$elements:.:"
        else
            [ -z "$quiet" ] && echo >&2 "# REMOVED: Empty entry (would work like '.')"
        fi
    else
        [ -z "$quiet" ] && echo >&2 "# REMOVED: Path element \"$p\": Directory not found;"
    fi
done
IFS="$IFS_SAVE"

elements=$(echo "$elements" | sed "s/::\+/:/g;s/^://;s/:$//")

if [ -z "$envName" ]; then
    [ -z "$quiet" ] && echo >&2 "# No variable name given (-n)"
    echo "$elements"
    exit 0
fi

printf "%s=%q;\n" "$envName" "$elements"
echo "export $envName"

