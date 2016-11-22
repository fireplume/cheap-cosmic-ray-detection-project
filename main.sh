#!/bin/bash

if [[ $# -lt 3 || $# -gt 5 ]]; then
    echo
    echo "Usage: $(basename $0) <ramdrive> <size> <time> <ascii> [-k|-M]"
    echo
    echo "ramdrive: path to ramdrive"
    echo "size:     amount of memory to use, unit determined by -k|-M"
    echo "time:     time in seconds between verification interval of the memory"
    echo "ascii:    Value can be anything between 1-255. If you want to fill with 'a' character, look up at an ASCII table"
    echo "          So, for 'a', you could use either one of 97, 0x61 or 0141 (which are respectively a decimal, hexadecimal and octal value)"
    echo "-k:       memory size refers to KB"
    echo "-M:       memory size refers to MB (default)"
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

# Binary value used to fill file shall be 8 bits (0-255)
binary_value=`printf "%d" $4`
if [[ $binary_value -lt 1 || $binary_value -gt 255 ]]; then
    echo "Value entered for filling file must be in range [1-255]"
    exit 1
fi

# If $5 not set, initialize to -M for megabytes
memory_unit=${5:--M}

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

echo "$initfile $binary_value \"cosmic-screen\" $memory_size $memory_unit"
$initfile $binary_value "cosmic-screen" $memory_size $memory_unit
if [[ $? != 0 ]]; then
    echo "Initialization of memory failed, exiting"
    exit 1
fi

echo "$checkfile \"cosmic-screen\" $binary_value $check_interval"
$checkfile "cosmic-screen" $binary_value $check_interval
