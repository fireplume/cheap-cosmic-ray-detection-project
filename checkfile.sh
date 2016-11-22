#!/bin/bash

# Copyright (c) 2016 Mathieu Comeau
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Convert ascii var to binary value
function str_to_bin
{
    # String representing binary value in hex format for feeding into echo -n -e
    local hex_str=`printf '\\\\x%x' $1`
    # Variable name to set is passed as second parameter
    local caller_var_name=$2

    # Here we have our binary character value on 8 bits
    local bin=`echo -n -e $hex_str`

    eval "$caller_var_name"=$bin
}

function jackpot
{
    local memstring=$1
    h=`echo -n -e $memstring | hexdump -C`
    echo "Cosmic ray!"
    echo "Here is the faulty block:"
    echo "$h"
    date
    exit 1
}

# Note that this function works as a child process
function verify
{
    local filedesc=$1
    local size_to_verify=$2
    local memstring
    local size_verified=0

    # Set IFS
    IFS=$our_ifs

    # verify 1kb at a time
    while read -r -n$verification_block_size -u$filedesc memstring; do
        if [[ !($memstring =~ $refstrblock) && (${#memstring} -ne 0) ]]; then
            jackpot $memstring
        fi

        # We only need to verify $size_to_verify amount of meomry, $verification_block_size at a time
        size_verified=$((size_verified+verification_block_size))
        if [[ $size_verified -ge $size_to_verify ]]; then
            break
        fi
    done

    IFS=$reg_ifs

    if [[ $size_verified -ne $size_to_verify ]]; then
        # How likely would it be to hit our reading IFS?
        echo "Size verified:  $size_verified"
        echo "Size to verify: $size_to_verify"
        echo "Cosmic ray hit us right into the IFS?!?!"
        jackpot $memstring
    fi
}

######################################################
# Main

if [[ $# != 3 ]]; then
    echo
    echo "Usage $(basename $0) <filename> <ascii> <time>"
    echo
    echo "filename: name of file to verify"
    echo "time:     time in seconds between verification interval of the memory"
    echo "ascii:    Value can be anything between 1-255. If you want to fill with 'a' character, look up at an ASCII table"
    echo
    echo "Example use: Verify every hour (3600 seconds) that file 'buffer' is filled with NULL characters:"
    echo "   $0 buffer 0 3600"
    echo
    exit 0
fi

filename=$1
# not really a binary value yet, still a string representing our binary value
binary_value=`printf "%d" $2`
check_interval=$3

#############################
# We need a an IFS that's different from our binary value
declare -g our_ifs=$(((binary_value+1)%255))
# get binary value for our ifs
str_to_bin $our_ifs "our_ifs"

declare -g reg_ifs=$IFS

#############################
# Check value provided
if [[ $binary_value -lt 1 || $binary_value -gt 255 ]]; then
    echo "Value entered for filling file must be in range [1-255]"
    exit 1
fi
str_to_bin $binary_value "c"

#############################
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

# Main loop
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

