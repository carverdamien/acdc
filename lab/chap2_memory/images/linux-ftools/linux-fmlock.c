#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <error.h>
#include <stdio.h>
#include <stdlib.h>

//#include <assert.h>
#define assert(X) { if(!(X)) { perror( #X ); return 1; } }

int main(int argc, char** argv)
{
	char* fname = argv[1];
	int time = atoi(argv[2]);
	void* ptr;
	int fd;
	struct stat stat;
	size_t len;

	fd = open(fname,O_RDONLY);
	assert(fd);
	assert(!fstat(fd, &stat));
	len = stat.st_size;
	ptr = mmap(NULL, len, PROT_READ, MAP_SHARED, fd, 0);
	assert(ptr);
	assert(!mlock(ptr, len));
	sleep(time);
	assert(!munlock(ptr, len));
	munmap(ptr, len);
	close(fd);
	return 0;
}
