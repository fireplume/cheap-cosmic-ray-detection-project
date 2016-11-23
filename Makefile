all : seek checkfile

seek : seek.c
	gcc -Wno-format -o seek seek.c
checkfile : checkfile.c
	gcc -Wno-format -o checkfile checkfile.c
