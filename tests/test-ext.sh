#!/bin/bash
#
# FILE: test-ext.sh
#
# ABSTRACT: Tests the script "extract"
#
# NOTE: If you renamed the extract scrip adjust the variable "extract" below.
#
# This scripts creates different archives and later tries to extract them using
# the command 'extract'.
#
# If the creation of an archive fails, this will be remembered and reported at
# the end of the script execution. Most likly this will be due to a not
# installed program.
#
# After the test archives are created they will be extracted in different ways.
# If extract fails an error is reported and execution is stopped.
#
# Following tests are made:
# 1) list content (doesn't check output, just return code)
# 2) extract in current directory
# 3) extract into directory build from archive name (extract -D <file>)
# 4) extract into given directory (extract -d <dir> <file>)
#
# In this cases <dir> and <file> will also be checked with a name that contains
# a space.
#
# For all archives which file type should be detected by its content (using
# /bin/file -bz <file>) the file extension is altered to force detection by
# content.
#
# This script creates a test directory to operate in. This directory is not
# deleted at the end of the execution and it contains the test archives and
# the logfile.
#
# AUTHOR: Ralf Schandl
#

script_dir=$(cd "$(dirname "$0")" 2>/dev/null && echo "$PWD")
script_name=$(basename "$0")


echo "--------------------------------------"
echo "Test script: $script_name"

# Actual name of executable script
extract="ext"

# test directory for test data
testdir="testdir.extract-test"

# Logfile inside the test directory
logfileBasename="extract-test.log"

OK="[01;32mOK[0m"
ERROR="[01;31mERROR[0m"
WARN="[33mWARNING[0m"

eval "$(resize)"
if [[ -n "$COLUMNS" ]]; then
    (( OK_COL   = COLUMNS - 6 ))
    (( ERR_COL  = COLUMNS - 9 ))
    (( WARN_COL = COLUMNS - 11 ))
else
    OK_COL=74
    ERR_COL=71
    WARN_COL=69
fi
OK_SUFFIX="[${OK_COL}G[[01;32mOK[0m]"
ERROR_SUFFIX="[${ERR_COL}G[[01;31mERROR[0m]"
WARN_SUFFIX="[${WARN_COL}G[[33mWARNING[0m]"

export PATH=$script_dir/..:$script_dir:$PATH

function errorexit
{
    echo ""
    echo "---------[ ${ERROR} ]------------------------------------------------------------"
    echo "see logfile $logfile"
    echo ""
    echo "Here are the last 10 lines:"
    echo ""
    tail -10 "$logfile"
    exit 1
}


#
# Write message to log file
#
function log
{
    echo "$@" >>"$logfile"
}

#
# Write message to stdout and to logfile
#
function msg
{
    echo "$@"
    echo "$@" >>"$logfile"
}

#
# Current test title to stdout (without newline) and to the
# logfile (with newline).
#
# When printing to stdout no newline is added, so that a following call
# to msgTestOK/ERROR/WARNING prints on the same line.
#
function msgTest
{
    echo -n "$@"
    echo "$@" >>"$logfile"
}

#
# Report test successful to stdout (colored output) and to the
# logfile (normal text).
#
function msgTestOK
{
    echo "$OK_SUFFIX"
    echo -e "\tOK" >>"$logfile"
}

#
# Report test error to stdout (colored output) and to the
# logfile (normal text).
#
function msgTestERROR
{
    echo "$ERROR_SUFFIX"
    echo -e "\tERROR (${BASH_LINENO[*]})" >>"$logfile"
}

#
# Report test warning to stdout (colored output) and to the
# logfile (normal text).
#
function msgTestWARNING
{
    echo "$WARN_SUFFIX"
    echo -e "\tWARNING (${BASH_LINENO[*]})" >>"$logfile"
}


packErrors=""
function registerPackError
{
    packErrors="${packErrors}    $1\n"
}

function pack
{
    cmd=$1
    log "---[ pack ]-----------------------------------"
    msgTest "$cmd"
    eval "$1" >> "$logfile" 2>&1
    if [[ $? -eq 0 ]]; then
        msgTestOK
    else
        #msgTestERROR
        msgTestWARNING
        registerPackError "$cmd"
        [[ -e "$2" ]] && rm "$2"
    fi
}

function testSelftest
{
    cmd="$extract -T"
    log "---[ Test Selftest ]---------------------------"

    rcOk=true
    msgOk=true
    msgTest "$cmd"
    res=$($cmd 2>&1)
    rc=$?

    log "RC: $rc"
    log "Output:"
    log "$res"
    log "--EndOutput--"

    local msg="OK"
    if echo "$res" | grep "Not Found" >/dev/null 2>&1; then
        msg="WARN"
        log "Warning: output contains String 'Not Found'"
    fi

    if [[ $rc -ne $expRc ]]; then
        msg="ERROR"
        log "Expected RC: $expRc"
    fi

    case $msg in
        OK)
        msgTestOK
        ;;
        WARN)
        msgTestWARNING
        ;;
        ERROR)
        msgTestERROR
        errorexit
        ;;
        *)
        ;;
    esac
}
#
# Test RC and Output of a command
#
function testRcMsg
{
    cmd=$1
    expRc=$2
    expTxt=$3

    log "---[ Test RC and messages ]--------------------"

    rcOk=true
    msgOk=true
    msgTest "$cmd"
    res=$($cmd 2>&1)
    rc=$?

    log "RC: $rc"
    log "Output:"
    log "$res"
    log "--EndOutput--"

    if [[ $rc -ne $expRc ]]; then
        rcOk=false
        log "Expected RC: $expRc"
    fi

    if [[ -n "$expTxt" ]]; then
        if [[ 1 -ne $(echo "$res" | grep -c "$expTxt") ]]; then
            msgOk=false
            log "Expected Text: $expTxt"
        fi
    fi

    if [[ $rcOk == false ]]; then
        msgTestERROR
        errorexit
    elif [[ $msgOk == false ]]; then
        msgTestERROR
        errorexit
    else
        msgTestOK
    fi
}

#
# Test list archive content. Just checks that RC is 0.
#
function testList
{
    f=$1

    log "---[ list ]-----------------------------------"
    log "File: $f"
    msgTest "$extract -l \"$f\""
    $extract -l "$f" >> "$logfile" 2>&1
    if [[ $? -eq 0 ]]; then
        msgTestOK
    else
        msgTestERROR
        errorexit
    fi
}

#
# Test archives that contain a directory tree
#
function testExtract
{
    f=$1
    d=$2

    # special handling for packer that don't support empty dirs
    case $f in
        *.zoo*)
        cmpTarget=$ORGaNoEmptyDir
        ;;
        *)
        cmpTarget=$ORGa
        ;;
    esac


    log "---[ extract ]--------------------------------"
    log "File: $f"
    case $f in
        *.jar*)
            # JAR always creates a directory META-INF - ignore it
            dirIgnore="--exclude=META-INF"
            ;;
    esac
    if [[ -z "$d" ]]; then
        msgTest "$extract \"$f\""
        $extract "$f" >> "$logfile" 2>&1
        log "Diff:"
        diff -r $dirIgnore "$cmpTarget" a >> "$logfile" 2>&1
        if [[ $? -eq 0 ]]; then
            #echo "extract \"$f\" ${OK_SUFFIX}"
            msgTestOK
        else
            #echo "extract \"$f\" ${ERROR_SUFFIX}"
            msgTestERROR
            errorexit
        fi
        rm -rf a
        [ -d META-INF ] && rm -rf META-INF
    elif [[ "$d" == "-D" ]]; then
        tdir=$(echo "$f" | sed 's/\.[^\.][^\.]*$//')
        tdir=$(basename "$tdir" .tar)
        log "Target: $tdir"
        msgTest "$extract -D \"$f\""
        $extract -D "$f" >> "$logfile" 2>&1
        log "Diff:"
        diff -r $dirIgnore "$cmpTarget" "$tdir/a" >> "$logfile" 2>&1
        if [[ $? -eq 0 ]]; then
            msgTestOK
        else
            msgTestERROR
            errorexit
        fi
        rm -rf "$tdir"
    else
        log "Target: $d"
        msgTest "$extract -d \"$d\" \"$f\""
        $extract -d "$d" "$f" >> "$logfile" 2>&1
        log "Diff:"
        diff -r $dirIgnore "$cmpTarget" "$d/a" >> "$logfile" 2>&1
        if [[ $? -eq 0 ]]; then
            msgTestOK
        else
            msgTestERROR
            errorexit
        fi
        rm -rf "$d"
    fi
}

function testSingleDir
{
    f=$1

    # special handling for packer that don't support empty dirs
    case $f in
        *.zoo*)
        cmpTarget=$ORGaNoEmptyDir
        ;;
        *)
        cmpTarget=$ORGa
        ;;
    esac

    mkdir marchTest
    cd marchTest || exit 1

    f="../$f"

    log "---[ extract ]--------------------------------"
    log "File: $f"
    tdir=$(echo "$f" | sed 's/\.[^\.][^\.]*$//')
    tdir=$(basename "$tdir" .tar)
    log "Target: $tdir"
    msgTest "$extract -S \"$f\""
    $extract -S "$f" >> "$logfile" 2>&1
    log "Diff:"
    diff -r "$cmpTarget/" "$tdir/" >> "$logfile" 2>&1
    if [[ $? -eq 0 ]]; then
        msgTestOK
    else
        msgTestERROR
        errorexit
    fi

    cd ..
    rm -rf "marchTest"
}

function testSingleDir2
{
    f=$1

    cmpDir="a"
    # special handling for packer that don't support empty dirs
    case $f in
        *.zoo*)
            cmpTarget=$ORGaNoEmptyDir
            ;;
        *.jar*)
            # jar always handled like -D because of META-INF
            cmpDir=$(echo "$f" | sed 's/\.[^\.][^\.]*$//')
            cmpDir=$(basename "$cmpDir" .tar)
            cmpDir="${cmpDir}/a"
            cmpTarget=$ORGa
            ;;
        *)
            cmpTarget=$ORGa
            ;;
    esac

    mkdir marchTest
    cd marchTest || exit 1

    f="../$f"

    log "---[ extract ]--------------------------------"
    msgTest "$extract -S \"$f\""
    $extract -S "$f" >> "$logfile" 2>&1
    log "Diff:"
    diff -r "$cmpTarget" "$cmpDir" >> "$logfile" 2>&1
    if [[ $? -eq 0 ]]; then
        #echo "extract \"$f\" ${OK_SUFFIX}"
        msgTestOK
    else
        #echo "extract \"$f\" ${ERROR_SUFFIX}"
        msgTestERROR
        errorexit
    fi

    cd ..
    rm -rf "marchTest"
}

#
# Test archives that only compress a single file (like gzip, bzip2)
#
function testExtractSingleFile
{
    f=$1
    d=$2

    log "--------------------------------------"
    log "File: $f"
    if [[ -z "$d" ]]; then
        msgTest "$extract \"$f\""
        $extract "$f" >> "$logfile" 2>&1
        log "Diff:"
        diff "$ORGcc" cc >> "$logfile" 2>&1
        if [[ $? -eq 0 ]]; then
            msgTestOK
        else
            msgTestERROR
            errorexit
        fi
        rm cc
    elif [[ "$d" == "-D" ]]; then
        tdir=$(echo "$f" | sed 's/\.[^\.][^\.]*$//')
        tdir=$(basename "$tdir" .tar)
        log "Target: $tdir"
        msgTest "$extract -D \"$f\""
        $extract -D "$f" >> "$logfile" 2>&1
        log "Diff:"
        diff -r "$ORGcc" "$tdir/cc" >> "$logfile" 2>&1
        if [[ $? -eq 0 ]]; then
            msgTestOK
        else
            msgTestERROR
            errorexit
        fi
        rm -rf "$tdir"
    else
        log "Target: $d"
        msgTest "$extract -d \"$d\" \"$f\""
        $extract -d "$d" "$f" >> "$logfile" 2>&1
        log "Diff:"
        diff "$ORGcc" "$d/cc" >> "$logfile" 2>&1
        if [[ $? -eq 0 ]]; then
            msgTestOK
        else
            msgTestERROR
            errorexit
        fi
        rm -rf "$d"
    fi
}


#---------[ MAIN ]-------------------------------------------------------------

# create test directory

if [[ -d $testdir ]]; then
    echo "Deleting old test directory \"$testdir\" ..."
    rm -rf $testdir
fi
echo "Creating new test directory \"$testdir\" ..."
mkdir $testdir
logfile=$(readlink -m "$testdir")/$logfileBasename
echo "Logfile: $logfile"
cd "$testdir" || exit 1

log "Test started $(date)"
log ""
log "Executable script name: \"$(type $extract)\""
log ""
log "ext: " "$(command -v ext)"

echo "Executable script name: \"$(type $extract)\""

# Create directory tree and testfiles to be archived into test archives
mkdir -p a/b
mkdir -p a/c
mkdir -p a/c/d/e

for p in $(find a -type d -print); do
    ls -R /etc > "$p/aa" 2>&1
    head -c 1453 /dev/urandom > "$p/bb"
done
# also an empty directory (not supported in zoo, so special handling in testExtract)
mkdir -p a/b/x

head -c 753 /dev/urandom > ./cc

msg "---------[ Run extract-internal test ]----------------------------------------"
#testRcMsg "$extract -T" 0 "Checking programms ..."
testSelftest
echo""

msg "---------[ Test RC and output ]-----------------------------------------------"
testRcMsg "$extract" 0 "Extracts arbitrary archives"
#testRcMsg "$extract -?" 0 "Extracts arbitrary archives"
testRcMsg "$extract --help" 0 "Extracts arbitrary archives"
testRcMsg "$extract -d" 1 "ERROR: Missing argument for option '-d'"
testRcMsg "$extract -x" 1 "ERROR: Unknown option: '-x'"
testRcMsg "$extract -D -x" 1 "ERROR: Unknown option: '-x'"
testRcMsg "$extract -D -- -x" 1 "ERROR: File not found: -x"
testRcMsg "$extract halodrin" 1 "ERROR: File not found: halodrin"
testRcMsg "$extract -D -d xy" 1 "Can't use '-d' with other options"
testRcMsg "$extract -D -d 'x y'" 1 "Can't use '-d' with other options"

# test invalid archive file
touch xy.zip
testRcMsg "$extract xy.zip" 1
rm xy.zip

# extract to a directory, that can't be created as file with same name exists
touch xy
zip xy.zip xy >/dev/null
testRcMsg "$extract -D xy.zip" 1 "ERROR: Can't create directory \"xy\" - file of same name exists"
testRcMsg "$extract -d xy xy.zip" 1 "ERROR: Can't create directory \"xy\" - file of same name exists"

# Test unkn$own file type
testRcMsg "$extract xy" 1 "ERROR: xy: Cannot determine file type (mime-type: 'inode/x-empty', compressed-encoding: '')"
rm xy.zip xy

# Create test archives
# For archives that can hold multiple files:
#   Pack the subdir 'a' into an archive 'a.<extension>'
# For archives that only compress a single file:
#   Pack the file 'cc' to a file 'cc.<extension>'
#
# All created archives will later be tested.

msg "---------[ Creating test archives ]-------------------------------------------"
pack "tar -cvf arch.tar a" arch.tar
pack "tar -czvf arch.tar.gz a" arch.tar.gz
pack "tar -czvf arch.tar.gz a" arch.tar.gz
pack "tar -cjvf arch.tar.bz2 a" arch.tar.bz2
pack "tar -cvf - a | 7z a -si arch.tar.7z" arch.tar.7z
pack "tar -cvf - a | lzip -o arch.tar" arch.tar.lz
pack "tar --lzma -cvf arch.tar.lzma a" arch.tar.lzma
pack "tar --xz -cvf arch.tar.xz a" arch.tar.xz

pack "gzip -c cc >cc.gz" cc.gz
pack "bzip2 -c cc >cc.bz2" cc.bz2
pack "lzip -c cc >cc.lz" cc.lz
pack "xz -c cc >cc.xz" cc.xz

pack "zip -r arch.zip a/" arch.zip
pack "jar -cf arch.jar a/" arch.jar
pack "arj a -a1 -r arch.arj a/" arch.arj
pack "rar a -r arch.rar a/" arch.rar
pack "7z a arch.7z a" arch.7z

pack "find a -print | zoo aI arch" arch.zoo

pack "find a -print | cpio -o -F arch.cpio" arch.cpio

# create ISOs with different extensions
mkdir xx
cp -R a xx
# Joliet extension
pack "mkisofs -joliet-long -o arch.j.iso xx" arch.j.iso
# Rock Ridge extension
pack "mkisofs -R -o arch.r.iso xx" arch.r.iso
# Joliet and Rock Ridge extensions
pack "mkisofs -R -joliet-long -o arch.rj.iso xx" arch.rj.iso
rm -rf xx

# create a fake debian package
mkdir -p xx/DEBIAN
cp -R a xx
cat > xx/DEBIAN/control <<EOF
Package: acme
Version: 1.0
Section: web
Priority: optional
Architecture: all
Essential: no
Depends: libwww-perl, acme-base (>= 1.2)
Pre-Depends: perl
Recommends: mozilla | netscape
Suggests: docbook
Installed-Size: 1024
Maintainer: Joe Brockmeier <jzb@dissociatedpress.net>
Conflicts: wile-e-coyote
Replaces: sam-sheepdog
Provides: acme
Description: The description can contain free-form text
             describing the function of the program, what
             kind of features it has, and so on.
EOF

pack "dpkg -b xx arch.deb" arch.deb
rm -rf xx


pack "cd a; tar -cvf ../march.tar aa b bb c; cd .." march.tar
pack "cd a;tar -czvf ../march.tar.gz aa b bb c;cd .." march.tar.gz
pack "cd a;tar -czvf ../march.tar.gz aa b bb c;cd .." march.tar.gz
pack "cd a;tar -cjvf ../march.tar.bz2 aa b bb c;cd .." march.tar.bz2
pack "cd a;tar -cvf - aa b bb c | 7z a -si ../march.tar.7z;cd .." march.tar.7z
pack "cd a;tar -cvf - aa b bb c | lzip -o ../march.tar;cd .." march.tar
pack "cd a;tar --lzma -cvf ../march.tar.lzma aa b bb c;cd .." march.tar.lzma
pack "cd a;zip -r ../march.zip aa b bb c/;cd .." march.zip
pack "arj a -a1 -e1 -r march.arj a/ " march.arj
pack "cd a;rar a -r ../march.rar aa b/ bb c/;cd .." march.rar
pack "cd a;7z a ../march.7z aa b bb c;cd .." march.7z
pack "cd a;find . -print | zoo aI ../march;cd .." march.zoo
pack "cd a;find . -print | cpio -o -F ../march.cpio;cd .." march.cpio
pack "mkisofs -R -joliet-long -o march.rj.iso a" march.rj.iso
pack "mkisofs -joliet-long -o march.j.iso a" march.j.iso
pack "mkisofs -R -o march.r.iso a" march.r.iso


#
# Don't know how to build a test RPM -- no test
#

# Copy all archives, so they have a space in their name
for fn in arch.*; do
    cp "$fn" "arch $fn"
done

# Copy all archives that should be detectable by file type and change their
# extension. The archive type can then only be detected by file content.
for fn in arch.*; do
    case $fn in
        # /bin/file can't look into 7z or lzma archives, hence can't detect the
        # tar inside
        *.t7z | *.tar.7z | *.tar.lzma)
        continue
        ;;
        *)
        cp "$fn" "Detect-${fn}Detect"
        ;;
    esac
done

# save packed dir and file for compare
mv a org.a
cp -r org.a org.a.noemptydir
rm -r org.a.noemptydir/b/x
mv cc org.cc

ORGa=$(readlink -m "org.a")
ORGaNoEmptyDir=$(readlink -m "org.a.noemptydir")
ORGcc=$(readlink -m "org.cc")

warnCount=0
msg ""
msg "---------[ Testing extract ]--------------------------------------------------"
for fn in arch*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        msgTest "$fn has size 0 -- ignored"
        msgTestWARNING
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testList "$fn"
    testExtract "$fn"
    testExtract "$fn" "-D"
    testExtract "$fn" "subdir"
    testExtract "$fn" "sub dir"
done

for fn in Detect-*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        msgTest "$fn has size 0 -- ignored"
        msgTestWARNING
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testExtract "$fn"
done

for fn in cc.*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        msgTest "$fn has size 0 -- ignored"
        msgTestWARNING
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testExtractSingleFile "$fn"
    testExtractSingleFile "$fn" "-D"
    testExtractSingleFile "$fn" "subdir"
    testExtractSingleFile "$fn" "sub dir"
done

# Test with relative path
mkdir test2
cd test2 || exit 1
for fn in ../a*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        msgTest "$fn has size 0 -- ignored"
        msgTestWARNING
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testList "$fn"
    testExtract "$fn"
    #testExtract "$fn" "-D"
    #testExtract "$fn" "subdir"
    #testExtract "$fn" "sub dir"
done

for fn in ../cc.*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        echo "$fn has size 0 -- ignored ${WARN_SUFFIX}"
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testExtractSingleFile "$fn"
    #testExtractSingleFile "$fn" "-D"
    #testExtractSingleFile "$fn" "subdir"
    #testExtractSingleFile "$fn" "sub dir"
done
cd ..

for fn in march.*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        echo "$fn has size 0 -- ignored ${WARN_SUFFIX}"
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testSingleDir "$fn"
done

for fn in arch.*; do
    if [[ $(stat -c "%s" "$fn") -eq 0 ]]; then
        echo "$fn has size 0 -- ignored ${WARN_SUFFIX}"
        (( warnCount = warnCount + 1 ))
        continue
    fi

    testSingleDir2 "$fn"
done


msg ""
msg "---------[ Done ]-------------------------------------------------------------"
msg "All Tests ${OK}"
msg ""
msg "Logfile: $logfile"
msg ""
if [[ $warnCount -gt 0 ]]; then
    msg "$WARN: $warnCount warnings occured. See logfile."
    msg ""
fi
if [[ -n "$packErrors" ]]; then
    msg "${WARN}: Not all supported packer/unpacker could be tested."
    msg "Most likely they are just not installed. See logfile."
    msg "The following pack-commands failed:"
    msg -e "$packErrors"
    msg ""
fi
msg "No tests implemented for:"
msg "   *.rpm    RPM Package Management "
msg "   *.chm    MS Windows HtmlHelp Data"
msg "   *.msi    MS Installer"
msg ""
msg ""

log "Test finished $(date)"
log ""

#---------[ END OF FILE test-ext.sh ]------------------------------------------
