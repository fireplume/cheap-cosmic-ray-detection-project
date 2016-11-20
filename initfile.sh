#!/bin/bash

# Hmm, it feels so serious to put this in my script. Why so serious? Ahh, let's do it:
#
# Copyright (c) 2016 Mathieu Comeau
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Note: that script is not meant to necessarily be optimal. I learned a few things about bash along
# the way that I just left here with some comments so it can serve as a reminder in the future.

# Global vars
declare -g fillchar
declare -g filename
declare -g sizeinMB
declare -g block_size_kb

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
    if [[ ($index -gt $nb_param) || $(egrep "^-" <<< $next_param)  ]]; then
        echo "Bad usage, missing argument for $param : ${next_param:-<not set>}"
        exit 1
    fi
}

function parse_command_line
{
    if [[ ($# -lt 3) || ($# -gt 6) ]]; then
        echo
        echo "Usage: $0 <char> <filename> <size MB> [-n] [-b block_size]"
        echo
        echo "This program creates(overwrite) and fills given filename with specified char up to specifed size."
        echo "Originally meant to be run on a ramdisk, -n disables the ramdisk check"
        echo "Char can be any regular character or octal value \\000 as accepted by 'tr'"
        echo
        echo "-b block_size: size in KB of data read/write at a time for
the file filling, defaults to 128KB. Must be a multiple of
4 and less than or equal to 16384"
        echo
        echo "Example. Create a file named buf and fill it with 256MB of null characters, 512KB at a time:"
        echo "   $0 \"\\000\" buf 256 -b 512"
        echo
        exit 0
    fi

    fillchar=$1
    filename=$2
    sizeinMB=$3
    # default value:
    block_size_kb=128

    ##################################################
    # Following takes advantage of parameter expansion
    # to assign a value of 1 to our variable

    if [[ $4 != "-n" ]]; then
        skip_ramdisk_check=0
    else
        # If $4 is equal to '-n', substitute matched pattern, '-n', for 1. The '#' is there to force
        # matching from beginning of variable value such that something like --n or -a-n wouldn't work.
        # Yes... it's overkill for just var=1.
        skip_ramdisk_check=${4/#-n/1}
    fi

    ##############################################
    # Let's practice options parsing 
    # without destroying them (shift), although
    # we have only a copy in this function.

    for ((i=4; $#+1-$i; i=i+1)) do
        # ${!i} takes on the value of $4, $5, following i's value
        # It's the '!' that does the magic here, instead of just referring
        # to $i.
        case ${!i} in
            -b)
                b=$((i+1))
                is_next_param $((i+1)) $# ${!i} ${!b}
                i=$((i+1))
                block_size_kb=${!i}
                block_size_kb=$(((block_size_kb/4)*4))

                if [[ $block_size_kb -gt 16384 ]]; then
                    block_size_kb=16384
                fi
                ;;
            -n)
                # just skip, already handled up there
                ;;
            *)
                echo "Unknown parameter: ${!i}"
                ;;
        esac
    done
}

function assert_enough_memory
{
    local requested=$1
    local available

    # df -BM prints available memory in MB
    # NR==2 because the line of interest is the second one from df's output
    # The gensub commands reads as substitute the M for nothing for 4th field, assign to 'a', then print 'a'
    available=`df -BM . | gawk '{ if(NR==2) { a = gensub(/M/, "", "g", $4); print a } }'`

    if [[ $requested -gt $available ]]; then
       echo "You've requested more memory than is available"
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

    local mypwd=`pwd`

    # for each line of mount's output
    for line in `mount`; do
        
        # Check if the line matches "type tmpfs" and also check if the path we're in ($mypwd)
        # matches (=~) the mount path, 3rd field ($3) of the current line as extracted by gawk.
        if [[ $line =~ "type tmpfs" && $mypwd =~ $(gawk '{ print $3 }'  <<< $line) ]]; then
            ramdisk_flag=1
            break
        fi
    done

    # recover original IFS
    IFS=$bifs

    # assert we're on a ramdisk
    if ! [[ $ramdisk_flag == 1 ]]; then
       echo Not on a ramdisk, exiting!
       exit 1
    fi
}

########################################################
# MAIN

parse_command_line $@

if [[ $skip_ramdisk_check == 0 ]]; then
    assert_ramdisk
fi

assert_enough_memory $sizeinMB

memsize=$(($sizeinMB*1024*1024))
blocksize=$((block_size_kb*1024))
blockcount=$(($memsize/$blocksize))

# create memsize MB file
cmd="dd if=/dev/zero iflag=fullblock bs=$blocksize count=$blockcount | tr \"\\000\" \"$fillchar\" > $filename"
echo "Filling file with: $cmd"
$(eval $cmd)
echo "Done!"
