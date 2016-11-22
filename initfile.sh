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

# Note: that script is not meant to necessarily be optimal. I learned a few things about bash along
# the way that I just left here with some comments so it can serve as a reminder in the future.

# Global vars
declare -g fillchar
declare -g filename
declare -g requested_size
declare -g block_size_kb
declare -g skip_ramdisk_check=1
declare -g size_factor=$((1024*1024))
declare -g overwrite_flag=0
declare -g DEBUG=1

function debug_out
{
    if [[ $DEBUG == 1 ]]; then
        echo "DEBUG: $1"
    fi
}

function is_next_param
{
    local index=$1
    local nb_param=$2
    local param=$3
    local next_param=$4

    # if current index is greater than number of param or
    # next param starts with '-' (which normally means another option)
    # echo error message
    # Note that the <<< operator allows to use the content of a variable
    # and feed it into a command which usually needs a file as argument.
    if [[ ($index -gt $nb_param) || $(egrep "^-" <<< $next_param) ]]; then
        echo "Bad usage, missing argument for $param : ${next_param:-<not set>}"
        exit 1
    fi
}

function parse_command_line
{
    if [[ ($# -lt 3) || ($# -gt 7) ]]; then
        echo
        echo "Usage: $(basename $0) <ascii> <filename> <size> [-n] [-o] [-M|-k] [-b block_size]"
        echo
        echo "This program creates and fills given filename with specified ascii char up to specifed size."
        echo "Originally meant to be run on a ramdisk, -n disables the ramdisk check"
        echo "Ascii is a value between 1 and 255"
        echo
        echo "-b block_size: size in KB of data read/write at a time for
the file filling, defaults to 128KB. Must be a multiple of 4 and less than or equal to 16384.
The reason being that the check utility checks 4KB at a time."
        echo
        echo "-M: size specified is in MB (this is the default)"
        echo "-k: size specified is in KB"
        echo "-n: do not check for operation on a ramdisk, which was the original purpose of this script, as I didn't want to accidentally fill my hard drive."
        echo "-o: overwrite filename if it exists"
        echo
        echo "Example. Create a file named buffer and fill it with 256MB of null characters, 512KB at a time:"
        echo "   $0 0 buffer 256 -b 512"
        echo
        exit 0
    fi

    # fill char must correspond to 'tr' supported octal format
    fillchar=`printf "%d" $1`
    if [[ $fillchar -lt 1 || $fillchar -gt 255 ]]; then
        echo "Value entered for filling file must be in range [1-255]"
        exit 1
    fi

    fillchar=`printf "\\%03o" $1`
    filename=$2
    requested_size=$3
    # default value:
    block_size_kb=128

    ##############################################
    # Let's practice options parsing
    # without destroying them (shift), although
    # we have only a copy in this function.

    for ((i=4; $#+1-$i; i=i+1)) do
        # ${!i} takes on the value of $4, $5, following i's value
        # It's the '!' that does the magic here, instead of just referring
        # to $i.
        declare -n param
        case ${!i} in
            -b)
                # Check next param
                b=$((i+1))
                is_next_param $((i+1)) $# ${!i} ${!b}

                # Get next param
                i=$b
                block_size_kb=${!i}
                block_size_kb=$((((block_size_kb+3)/4)*4))

                if [[ $block_size_kb -gt 16384 ]]; then
                    block_size_kb=16384
                fi
                ;;
            -n)
                # Let's play with parameter substitution.
                # If param is equal to '-n', substitute matched pattern, '-n', for 1. The '#' is there to force
                # matching from beginning of variable value such that something like --n or -a-n wouldn't work.
                tmp=${!i}
                # Unfortunately, this doesn't work: skip_ramdisk_check=${${!i}/#-n/1}
                # And, yes, overkill for var=1, but I leave it there as I use this script also as a reference
                # for bash features
                skip_ramdisk_check=${tmp/#-n/1}
                ;;
            -M)
                size_factor=$((1024*1024))
                ;;
            -k)
                size_factor=1024
                ;;
            -o)
                overwrite_flag=1
                ;;
            *)
                echo "Unknown parameter: ${!i}"
                ;;
        esac
    done
}

function assert_enough_memory
{
    local requested_kb=$(($1/1024))
    local available_kb

    # df -k prints available memory in KB
    # NR==2 because the line of interest is the second one from df's output
    # The gensub commands reads as substitute the K for nothing for 4th field, assign to 'a', then print 'a'
    available_kb=`df -BK . | gawk '{ if(NR==2) { a = gensub(/K/, "", "g", $4); print a } }'`

    if [[ $requested_kb -gt $available_kb ]]; then
       echo "You've requested ($requested_kb KB) more memory than is available ($available_kb KB)"
       echo "If you already did a run of this script, erasing the file"
       echo "on your ram drive would fix your issue"
       exit 1
    fi
}

function assert_ramdisk
{
    local ramdisk_flag=0

    # make sure we're on a ram disk before filling up the space!

    # Backup internal field separator
    local bifs=$IFS

    # Set field separator to newline to be able to parse 'mount' output one line at a time,
    # if we don't do that, it will parse each non space token at a time, which is annoying.
    IFS="
"

    local mypwd=`pwd -P`

    # for each line of mount's output
    for line in `mount`; do

        mount_point=$(gawk '{ print $3 }'  <<< $line)
        # Check if the line matches "type tmpfs" and also check if the path we're in ($mypwd)
        # matches (=~) the mount path, 3rd field ($3) of the current line as extracted by gawk.
        if [[ ($line =~ "type tmpfs") && ($mypwd =~ "$mount_point") ]]; then
            ramdisk_flag=1
            break
        fi
    done

    # recover original IFS
    IFS=$bifs

    # assert we're on a ramdisk
    if [[ $ramdisk_flag != 1 ]]; then
       echo "Not on a ramdisk, exiting!"
       exit 1
    fi
}

########################################################
# MAIN

parse_command_line $@

if [[ $skip_ramdisk_check == 0 ]]; then
    assert_ramdisk
fi

# if file exists, delete it
if [[ -f $filename && ( $overwrite_flag == 1 ) ]]; then
   rm $filename
fi

memsize=$(($requested_size*size_factor))
blocksize=$((block_size_kb*1024))

if [[ $blocksize -gt $memsize ]]; then
    blocksize=$memsize
fi

blockcount=$(($memsize/$blocksize))

# Param in KB
assert_enough_memory $memsize

# create memsize MB file
cmd="dd if=/dev/zero iflag=fullblock bs=$blocksize count=$blockcount 2> /dev/null | tr \"\\000\" \"$fillchar\" > $filename"
echo "Filling file with: $cmd"
$(eval $cmd)
echo "Done!"
