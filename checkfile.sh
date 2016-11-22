#!/bin/bash

if [[ $# != 3 ]]; then
    echo
    echo "Usage $0 <filename> <character> <check interval in seconds>"
    echo
    echo "'character' can either be a regular character or an hex value of the form \\x00"
    echo
    echo "Example use: Verify every hour (3600 seconds) that file 'buffer' is filled with NULL characters:"
    echo "   $0 buffer \"\\x0\" 3600"
    echo
    exit 0
fi

filename=$1
c=`echo -n -e "$2"`
check_interval=$3

declare -g DEBUG=0

# Check seek util is availble
$(which seek > /dev/null 2>&1)
if [[ $? == 1 ]]; then
    echo "seek utility is not compiled or not in your path."
    echo "Add the utility to your path with: export PATH=\$PATH:<path to utility>"
    echo "For example: export PATH=\$PATH:/home/username/myutils"
fi

###################################################
# Build a 1KB block string of characters
declare -g verification_block_size=1024
for i in `seq 1 128`; do
    refstrblock="$refstrblock""$c$c$c$c$c$c$c$c"
done

###################################################
# Get file size and set size_factor depending of
# file size
filesize=`du -b $filename | awk '{ print $1 }'`
echo "File size: $filesize bytes"

base_offset=$((filesize/4))
size_kb=$((filesize/1024))

if [[ ($size_kb -lt 4) || ($(($size_kb%4)) != 0) ]]; then
    echo "This script is not meant to be run on files less than 4KB or"
    echo "which are not a multiple of 4KB"
    exit 1
fi

date

# Note that this function works as a child process
function verify
{
    local filedesc=$1
    local size_to_verify=$2
    local memstring
    local size_verified=0

    # verify 1kb at a time
    while read -n$verification_block_size -u$filedesc memstring; do
        if [[ $SPOTTED -eq 1 ]]; then
            break
        fi

        if [[ ($memstring != $refstrblock) && ($memstring != "") ]]; then
           h=`echo -n -e $memstring | hexdump -C`
           echo "Cosmic ray!"
           echo "$h"
           date
           exit 1
        fi

        if [[ $DEBUG -eq 1 ]]; then
            echo "Read: ${memstring}"
            echo "Ref:  ${refstrblock}"
            exit 1
        fi

        # We only need to verify $size_to_verify amount of meomry, $verification_block_size at a time
        size_verified=$((size_verified+$verification_block_size))
        if [[ $size_verified -ge $size_to_verify ]]; then
            break
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

        verify $i $base_offset &
        eval "v$i=$!"
    done

    # Wait for all jobs to be done
    status=0
    for i in `seq 4 7`; do
        v="v$i"
        wait ${!v}
        s=$?

        if [[ $DEBUG -eq 1 ]]; then
            echo "Thread $i status: $s"
        fi

        status=$((status|s))
        eval "exec $i>&-"
    done

    if [[ $status -eq 1 ]]; then
        exit 0
    fi

    # Tease the cosmic rays
    echo "Psst! pssst! Come on GeV particle!"

    # sleep for an hour
    sleep $check_interval
done

