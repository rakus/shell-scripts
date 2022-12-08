#!/bin/bash
#
# FILE: splitForEmail.sh
#
# ABSTRACT: Splits file to send it via email
#
# 1) Creates a hex or base64 dump of a file.
# 2) Split the dump file.
# 3) Zip the individual splits
# 4) Create a batch and a shell script to recreate the initial file.
#
# AUTHOR: Ralf Schandl
#

error_exit()
{
    echo >&2 "ERROR: $*"
    exit 1
}

usage()
{
    echo >&2 "Usage: splitForEmail.sh [-bx] file [ split-size ]"
    echo >&2 "   -b          Use base64 - smaller, faster - default"
    echo >&2 "   -x          Use xxd hexdumps (xxd comes with Vim)"
    echo >&2 "   file        Dump of this file is splitted and zipped"
    echo >&2 "   split-size  Maximum size of splitted files. Default: "
    echo >&2 "                 16m for hexdumps"
    echo >&2 "                 12m for base64"
    echo >&2 "               This should result in zipped files smaller 10m."
    echo >&2 ""
}

# handle options
while getopts "xb" o "$@"; do
    case $o in
        x)
            if [ -n "$ext" ]; then
                echo >&2 "Duplicate option. Either use '-x' or '-b'"
                exit 1
            fi
            ext=xxd
            ;;
        b)
            if [ -n "$ext" ]; then
                echo >&2 "Duplicate option. Either use '-x' or '-b'"
                exit 1
            fi
            ext=b64
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$ext" ]; then
    ext=b64
fi
# Resulting zips should be smaller 10m
[ "$ext" = "xxd" ] && splitsize=16m
[ "$ext" = "b64" ] && splitsize=12m

case $# in
    2) file=$1
        splitsize=$2
        ;;
    1) file=$1
        ;;
    *)
        usage
        exit 1
        ;;
esac

tgtFile="$(basename "$file")"

if [ "$ext" = "xxd" ]; then
    echo "Creating hexdump ..."
    if ! xxd "$file" "$tgtFile.xxd"; then
        error_exit "xxd \"$file\" \"$tgtFile.xxd\""
    fi
elif [ "$ext" = "b64" ]; then
    echo "Creating base64 ..."
    if ! base64 -w0 "$file" > "$tgtFile.b64"; then
        error_exit "base64 -w0 \"$file\" > \"$tgtFile.b64\""
    fi
else
    echo >&2 "Unknown extension: $ext"
fi

echo "Splitting ..."
if ! split -C "$splitsize" -a3 "$tgtFile.$ext" "$tgtFile.$ext."; then
    error_exit "split -C $splitsize -a3 \"$tgtFile.$ext\" \"$tgtFile.$ext.\""
fi

echo "Zipping splits ..."
for fn in "$tgtFile.$ext.a"??; do
    if ! zip "$fn.zip" "$fn"; then
        error_exit "zip \"$fn.zip\" \"$fn\""
    fi
    rm "$fn"
done

if [ "$ext" = "xxd" ]; then
    undump_cmd="xxd -r $tgtFile.xxd $tgtFile"
elif [ "$ext" = "b64" ]; then
    undump_cmd="base64 -d $tgtFile.b64 > $tgtFile"
fi

echo "Creating expand batch ..."
cat > expand.bat <<EOF

for /f "tokens=*" %%F in ('dir /b /on "$tgtFile.$ext.a??.zip"') do (
    unzip %%F
)

del "$tgtFile.$ext"
for /f "tokens=*" %%F in ('dir /b /on "$tgtFile.$ext.a??"') do (
    type %%F >> $tgtFile.$ext
)

$undump_cmd

EOF


echo "Creating expand shell script ..."
cat > expand.sh <<EOF
#!/bin/sh
for fn in $tgtFile.$ext.a??.zip; do
    unzip \$fn
done
rm -f "$tgtFile.$ext"
for fn in $tgtFile.$ext.a??; do
    cat "\$fn" >> "$tgtFile.$ext"
done
$undump_cmd
EOF


