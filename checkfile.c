/*
Program to put file descriptor pointer at an offset from the start.
*/
#include <sys/stat.h>   // fdopen
#include <fcntl.h>      // fdopen
#include <sys/types.h>  // off_t
#include <stdlib.h>     // atoi, malloc
#include <stdio.h>      // fprintf
#include <sys/stat.h>   // fstat
#include <unistd.h>     // fstat
#include <errno.h>      // errno
#include <sys/mman.h>   // mmap
#include <string.h>     // memset
#include <stdio.h>      // snprintf

#define FROM_BEGINNING_OF_FILE SEEK_SET

int main(int argc, char* argv[]) {

    if(argc != 5) {
        fprintf(stderr, "Usage: %s <offset> <length> <fd> <ascii>\n", argv[0]);
        return 0;
    }

    off_t offset  = (off_t) (atoi(argv[1]));
    int length    = atoi(argv[2]);
    int fd        = atoi(argv[3]);
    char ascii    = atoi(argv[4]);
    FILE* f       = NULL;
    struct stat statinfo;

    fprintf(stderr, "offset: %d length: %d fd:%d ascii:%c\n", (int)offset, length, fd, ascii);

    if((offset < 0) || (fd < 0)) {
        fprintf(stderr, "Offset and file descriptor must be positive integers: %d:%d\n", offset, fd);
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

    ///////////////////////////////////////////////////////
    // Check 1Kb at a time, so initialize an array with
    #define BLOCK_SIZE 1024

    char* ref_block = NULL;
    //ref_block = (char*)mmap(NULL, BLOCK_SIZE, 0, MAP_ANONYMOUS, 0, 0);
    ref_block = (char*)malloc(BLOCK_SIZE);
    //if(ref_block == (char*)-1) {
    if(ref_block == NULL) {
        fprintf(stderr, "Failed to allocated memory for ref block: %s\n", strerror(errno));
        return 1;
    }

    memset(ref_block, ascii, BLOCK_SIZE);

    char* data_block = NULL;
    data_block = (char*)mmap(NULL, length, PROT_READ, MAP_SHARED, fd, offset);

    // Read file descriptor and verify data until length exhasuted
    int bytes_verified=0;
    while((bytes_verified<length) && !strncmp(ref_block, data_block, BLOCK_SIZE)) {
        data_block      += BLOCK_SIZE;
        bytes_verified  += BLOCK_SIZE;
    }

    if(bytes_verified<length) {
        fprintf(stderr, "Stopped after %d bytes read\n", bytes_verified+offset);
        snprintf(ref_block, BLOCK_SIZE, "%s", data_block);
        printf(ref_block);
        free(ref_block);
        return 1;
    } else {
        return 0;
    }
}
