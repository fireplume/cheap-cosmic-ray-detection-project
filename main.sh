#!/bin/bash

if [[ $# -lt 3 || $# -gt 4 ]]; then
    echo
    echo "Usage: $0 <path to ram drive> <size of memory to put under test> <verification interval in seconds> [-k|-M]"
    echo
    echo "-k: memory size refers to KB"
    echo "-M: memory size refers to MB (default)"
    echo
    echo "To create a ramdrive: sudo mount -t tmpfs -o size=<> tmpfs <mount point>"
    echo "For example, create a 512MB ram drive named 'ramdrive' in your home:"
    echo "  cd ~"
    echo "  mkdir ramdrive"
    echo "  sudo mount -t tmpfs -o size=512M,sync tmpfs ramdrive"
    echo
    exit 0
fi

rampath=$1
memory_size=$2
check_interval=$3
memory_unit=${4:--M}

cd "$rampath"
if [[ $? != 0 ]]; then
   echo "Couldn't cd into $rampath"
   exit 1
fi

initfile=`which initfile.sh`
s1=$?
checkfile=`which checkfile.sh`
s2=$?
if [[ ($s1 != 0) || ($s2 != 0) ]]; then
    echo "initfile.sh and/or checkfile.sh not in your \$PATH environment variable!"
    exit 1
fi

# Note that initfile.sh needs to be fed with either a regular character or octal value as supported by 'tr'
echo "$initfile \"\000\" \"cosmic-screen\" $memory_size $memory_unit"
$initfile "\000" "cosmic-screen" $memory_size $memory_unit
if [[ $? != 0 ]]; then
    echo "Initialization of memory failed, exiting"
    exit 1
fi

# Note that checkfile.sh needs to be fed with either a regular character or hex value as supported by 'echo -e'
echo "$checkfile \"cosmic-screen\" \"\x00\" $check_interval"
$checkfile "cosmic-screen" "\x00" $check_interval
