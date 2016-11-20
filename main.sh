#!/bin/bash

if [[ $# != 2 ]]; then
    echo
    echo "Usage: $0 <path to ram drive> <size in MB to put under test>"
    echo
    echo "To create a ramdrive: sudo mount -t tmpfs -o size=<> tmpfs <mount point>"
    echo "For example, create a 512MB ram drive named 'ramdrive' in your home:"
    echo "  cd ~"
    echo "  mkdir ramdrive"
    echo "  sudo mount -t tmpfs -o size=512M tmpfs ramdrive"
    echo
    exit 0
fi

rampath=$1
size_MB=$2

cd "$rampath"
if [[ $? != 0 ]]; then
   echo "Couldn't cd into $rampath"
   exit 1
fi

# Note that initfile.sh needs to be fed with either a regular character or octal value as supported by 'tr'
echo "Initializing cosmic screen!"
. ../initfile.sh "\000" "cosmic-screen" $size_MB

# Note that checkfile.sh needs to be fed with either a regular character or hex value as supported by 'echo -e'
echo "Launching verification loop. Wait and see..."
. ../checkfile.sh "cosmic-screen" "\x00"
