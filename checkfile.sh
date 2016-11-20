#!/bin/bash

if [[ $# != 2 ]]; then
   echo "Usage $0 <filename> <character>"
   echo "'character' can either be a regular character or an hex value of the form \\x00"
   echo "Example use: Verify that file 'buffer' is filled with NULL characters:"
   echo "   $0 buffer \"\\x0\""
   exit 0
fi

filename=$1
c=`echo -n -e "$2"`

# Check seek util is availble
$(which seek > /dev/null 2>&1)
if [[ $? == 1 ]]; then
    echo "seek utility is not compiled or not in your path."
    echo "Add the utility to your path with: export PATH=\$PATH:<path to utility>"
    echo "For example: export PATH=\$PATH:/home/username/myutils"
fi

###################################################
# Build a 4KB block string of characters
for i in `seq 1 512`; do
    refstrblock="$refstrblock""$c$c$c$c$c$c$c$c"
done

###################################################
# Get file size in MB
filesize=`du -BM $filename | awk '{ s = gensub("M", "", "", $1); print s }'`
base_offset=$((filesize/4))

if [[ ($filesize -lt 4) || ($(($filesize%4)) != 0)]]; then
    echo "This script is not meant to be run on files less than 4MB or"
    echo "which are not a multiple of 4MB"
    exit 1
fi

date

function verify
{
    local filedesc=$1
    local memstring

    # verify 4kb at a time
    while read -n4096 -u$filedesc memstring; do
        if [[ ($memstring != $refstrblock) && ($memstring != "") ]]; then
           h=`echo -n -e $memstring | hexdump -C`
           echo "Cosmic ray!"
           echo "$h"
           date
           exit 0
        fi
    done
}

while true; do
    offset=0

    # launch 4 processes in parallel to verify the file
    # TODO: optimize with number of cpus reported in /proc/cpuinfo
    for i in `seq 4 7`; do
        eval "exec $i<> $filename"

        eval "seek $offset $i"
        status=$?
        if [[ $status != 0 ]]; then
            echo "Failed to seek proper position while verifying file, exit status: $status"
            exit 1
        fi

        offset=$(( offset + base_offset ))

        verify $i &
        eval "v$i=$!"
    done

    # Wait for all jobs to be done
    for i in `seq 4 7`; do
        v="v$i"
        wait ${!v}
        eval "exec $i>&-"
    done

    # Tease the cosmic rays
    echo "Psst! pssst! Come on GeV particle!"

    # sleep for an hour
    sleep 3600
done

