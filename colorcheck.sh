#!/bin/bash
#
# FILE: colorcheck.sh
#
# ABSTRACT: Display terminal colors
#
# AUTHOR: Ralf Schandl
#


testColor () {
    txt=$1
    fg=$2
    bg=$3

    if [[ $fg -eq 0 ]]; then
        printf "\033[%sm %s \033[00m" "$bg" "$txt"
    elif [[ $bg -eq 0 ]]; then
        printf "\033[%sm %s \033[00m" "$fg" "$txt"
    else
        printf "\033[%s;%sm %s \033[00m" "$fg" "$bg" "$txt"
    fi
}

bgColors="00 40 100 41 101 42 102 43 103 44 104 45 105 46 106 47 107"
fgColors="00 30 90 31 91 32 92 33 93 34 94 35 95 36 96 37 97"

/bin/echo -n "    "
for j in $bgColors; do
    [[ $j -lt 100 ]] && pad=" " || pad=""
    testColor "$j:$pad" 0 0
done
echo ""

for i in $fgColors; do
    /bin/echo -n "$i: "
    for j in $bgColors; do
        testColor 'Test' "$i" "$j"
    done
    echo ""
done

echo ""
echo "Testing TrueColor:"

eval "$(resize)"

awk -v COLS=$COLUMNS 'BEGIN{
    for (colnum = 0; colnum<COLS; colnum++) {
        r = 255-(colnum*255/(COLS-1));
        g = (colnum*510/(COLS-1));
        b = (colnum*255/(COLS-1));
        if (g>255) g = 510-g;
        printf "\033[48;2;%d;%d;%dm", r,g,b;
        printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
        printf "%s\033[0m", colnum%2 == 0?"/":"\\";
    }
    printf "\n";
}'

