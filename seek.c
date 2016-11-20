/*
Program to put file descriptor pointer at an offset from the start.
*/
#include <sys/stat.h>   // fdopen
#include <fcntl.h>      // fdopen
#include <sys/types.h>  // off_t
#include <stdlib.h>     // atoi
#include <stdio.h>      // fprintf
#include <sys/stat.h>   // fstat
#include <unistd.h>     // fstat
#include <errno.h>      // errno

#define FROM_BEGINNING_OF_FILE SEEK_SET

int main(int argc, char* argv[]) {

    if(argc != 3) {
        fprintf(stderr, "Usage: %s <offset in MB> <file descriptor>\n", argv[0]);
        return 0;
    }

    // Offset parameter is to be specified in MB
    off_t offset  = (off_t) (atoi(argv[1]) * 1024 * 1024);
    int fd        = atoi(argv[2]);
    FILE* f       = NULL;
    struct stat statinfo;

    if((offset < 0) || (fd < 0)) {
        fprintf(stderr, "Offset and file descriptor must be positive integers\n");
        return 1;
    }

    // File descriptor exists?
    f = fdopen(fd, "r");
    if(f==NULL) {
        fprintf(stderr, "Couldn't open file descriptor %d\n", fd);
        return 1;
    }

    // Regular file?
    if(fstat(fd, &statinfo)) {
        fprintf(stderr, "fstat error on file descriptor: errno: %s\n", strerror(errno));
        return 1;
    } else {
        if(!S_ISREG(statinfo.st_mode)) {
            fprintf(stderr, "FD is not a regular file\n");
            return 1;
        }
    }

    // Seek file to requested offset
    off_t current = lseek(fd, offset, FROM_BEGINNING_OF_FILE);

    if(current != offset) {
        fprintf(stderr, "Couldn't seek requested offset. Current offset is %i\n", (int)current);
        return 1;
    }

    return 0;
}
