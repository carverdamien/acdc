id="$(basename $(readlink -e .))"
dir="/data/${id}/"
memory=$((2**30))
inmemory=$((memory*40/100))
outofmemory=$((2*memory))

bigio=$((2**20))
smallio=$((bigio / 4))

echo "
define file name=fileinmemory,   path=${dir}, size=${inmemory},    prealloc, reuse
define file name=fileoutofmemory, path=${dir}, size=${outofmemory}, prealloc, reuse

define process name=process${id},instances=1
{
  # We can control event thread
  thread name=${id}evt,memsize=${bigio},instances=1
  {
    flowop eventlimit name=limit1
    flowop read name=evtread1, filename=fileinmemory, iosize=${smallio}, fd=3
    flowop read name=evtread2, filename=fileinmemory, iosize=${smallio}, fd=4
  }
  # We have no control over always thread
  thread name=${id}alw,memsize=${bigio},instances=1
  {
    # alw thread must help evt thread
    flowop read name=alwread1, filename=fileinmemory,    iosize=${bigio}, fd=15

    # alw thread must be slowed with a fileoutofmemory
    flowop read name=alwread2, filename=fileoutofmemory, iosize=${bigio}, fd=16
  }
}

eventgen rate = 0
create files
system \"/shared/linux-fadvise ${dir}/fileinmemory/00000001/00000001 POSIX_FADV_NORMAL\"
system \"/shared/linux-fadvise ${dir}/fileoutofmemory/00000001/00000001 POSIX_FADV_NORMAL\"
"
fadvise_active() {
if [ "${USE_FADVISE}" == "y" ] 
then
echo "system \"/shared/linux-fadvise ${dir}/fileinmemory/00000001/00000001 POSIX_FADV_WILLNEED\""
echo "system \"/shared/linux-fadvise ${dir}/fileoutofmemory/00000001/00000001 POSIX_FADV_NORMAL\""
fi
}
fadvise_inactive() {
if [ "${USE_FADVISE}" == "y" ]
then
echo "system \"/shared/linux-fadvise ${dir}/fileinmemory/00000001/00000001 POSIX_FADV_NORMAL\""
echo "system \"/shared/linux-fadvise ${dir}/fileoutofmemory/00000001/00000001 POSIX_FADV_NORMAL\""
fi
}
fmlock_init() { :; }
fmlock() {
LOCK_TIME=$1
if [ "${USE_FMLOCK}" == "y" ]
then
echo "system \"job /shared/linux-fmlock ${dir}/fileinmemory/00000001/00000001 ${LOCK_TIME}\""
fi
}
