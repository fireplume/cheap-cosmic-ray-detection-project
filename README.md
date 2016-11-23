# cheap-cosmic-ray-detection-project
Using RAM, try to detect soft errors which could be caused by cosmic ray

This project is meant to be run in a linux environment. I am running it on my Raspberry PI3.

https://en.wikipedia.org/wiki/Soft_error#Causes_of_soft_errors

Yes, the project title is catchy. There are other factors which may cause soft errors, see the link above for details. Still, the idea of using off the shelf memory to detect soft errors which could be due to cosmic ray was interesting to me, so I thought I'd make a little project about it.

```
------------------------------------------------------
Running the flow
------------------------------------------------------

1) Clone this project on your computer
2) Run 'make' to generate the 'seek' utility
3) Make sure all the shell and programs from the project are in your $PATH environment variable
4) Create a ram drive
5) Run main.sh <path to ramdrive> <memory to use for test>
6) After memory has been initialized, it doesn't matter if shell crashes.
You will lose the start date information, but you can follow up on the
memory verification later on by running the 'checkfile.sh' command that
'main.sh' printed on your screen in the ramdrive directory.

To see how to use individual tools, just type the tool name at command line to print its help.

------------------------------------
Complete flow example for 128MB use of RAM
Replace 128 by as big a number as
you can to increase chances of detecting
a cosmic ray:
------------------------------------

cosmic -> git clone git@github.com:fireplume/cheap-cosmic-ray-detection-project.git
Cloning into 'cheap-cosmic-ray-detection-project'...
X11 forwarding request failed on channel 0
remote: Counting objects: 20, done.
remote: Compressing objects: 100% (13/13), done.
remote: Total 20 (delta 5), reused 14 (delta 4), pack-reused 0
Receiving objects: 100% (20/20), 7.12 KiB | 0 bytes/s, done.
Resolving deltas: 100% (5/5), done.
Checking connectivity... done.

cosmic -> cd cheap-cosmic-ray-detection-project/
cosmic -> make
gcc -Wno-format -o seek seek.c
gcc -Wno-format -o checkfile checkfile.c
cosmic -> ls
checkfile checkfile.c checkfile.sh  initfile.sh  main.sh  Makefile  README.md  seek  seek.c
cosmic -> export PATH=$PATH:`pwd`

# Create 128MB ram drive
cosmic -> mkdir ramdrive
cosmic -> sudo mount -t tmpfs -o size=128M,sync tmpfs `pwd`/ramdrive
[sudo] password for fireplume:

# Launch tool for 128MB ram drive and verification every 3600 seconds, fill file with ascii character 97 ('a')
cosmic -> main.sh `pwd` 128 3600 97 -M
/tmp/exp/cheap-cosmic-ray-detection-project/initfile.sh 97 "cosmic-screen" 128 -M
Filling file with: dd if=/dev/zero iflag=fullblock bs=131072 count=1024 2> /dev/null | tr "\000" "\141" > cosmic-screen
Done!
/tmp/exp/cheap-cosmic-ray-detection-project/checkfile.sh "cosmic-screen" 97 3600
File size: 134217728 bytes
Wed Nov 23 07:20:53 EST 2016
Psst! pssst! Come on GeV particle!
^C
cosmic ->

# Launch back the verification after stopping 'main.sh':
cosmic -> cd ramdrive/

# Just check first 16 bytes of file for curiosity
cosmic -> head -c 16 cosmic-screen 
aaaaaaaaaaaaaaaa

# Relaunch
cosmic -> /tmp/exp/cheap-cosmic-ray-detection-project/checkfile.sh "cosmic-screen" 97 3600
Sun Nov 20 19:29:53 EST 2016
Psst! pssst! Come on GeV particle!
```
