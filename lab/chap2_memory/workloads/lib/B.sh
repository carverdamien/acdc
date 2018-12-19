id="$(basename $(readlink -e .))"
dir="/data/${id}/"
memory=$((2**30))
inmemory=$((memory*40/100))
outofmemory=$((2*memory))

bigio=$((2**20))
smallio=$((bigio / 4))
smallestio=$((2**16))

echo "
define file name=fileinmemory1,   path=${dir}, size=${inmemory},    prealloc, reuse
define file name=fileinmemory2,   path=${dir}, size=${inmemory},    prealloc, reuse
define file name=fileoutofmemory, path=${dir}, size=${outofmemory}, prealloc, reuse

define process name=process${id},instances=1
{
  # We can control event thread
  thread name=${id}evt,memsize=${bigio},instances=1
  {
    flowop eventlimit name=limit1
    flowop read name=evtread3, filename=fileinmemory2, iosize=${bigio}, fd=5
    flowop read name=evtread4, filename=fileinmemory2, iosize=${bigio}, fd=6
  }
  # We have no control over touch thread
  # Its goal is to keep fileinmemory1 in memory
  # but since it uses smallestio it should waste a lot of time on syscalls
  thread name=${id}tch,memsize=${smallestio},instances=1
  {
    flowop read random, name=tchread1, filename=fileinmemory1, iosize=${smallestio}, fd=7
  }
  # We have no control over always thread
  thread name=${id}alw,memsize=${bigio},instances=1
  { 
    flowop read name=alwread1, filename=fileinmemory1,   iosize=${bigio}, fd=9
    flowop read name=alwread2, filename=fileinmemory1,   iosize=${bigio}, fd=10

    # alw thread must be slowed with a fileoutofmemory
    flowop read name=alwread3, filename=fileoutofmemory, iosize=${smallio}, fd=11

    # Third touch to secure fileoutofmemory after loosing time on fileoutofmemory
    flowop read name=alwread4, filename=fileinmemory1,   iosize=${bigio}, fd=12
  }
}

eventgen rate = 0
create files
system \"/shared/linux-fadvise ${dir}/fileinmemory1/00000001/00000001 POSIX_FADV_NORMAL\"
system \"/shared/linux-fadvise ${dir}/fileinmemory2/00000001/00000001 POSIX_FADV_NORMAL\"
system \"/shared/linux-fadvise ${dir}/fileoutofmemory/00000001/00000001 POSIX_FADV_NORMAL\"
"
fadvise_active() {
if [ "${USE_FADVISE}" == "y" ] 
then
echo "system \"/shared/linux-fadvise ${dir}/fileinmemory1/00000001/00000001 POSIX_FADV_WILLNEED\""
echo "system \"/shared/linux-fadvise ${dir}/fileinmemory2/00000001/00000001 POSIX_FADV_WILLNEED\""
echo "system \"/shared/linux-fadvise ${dir}/fileoutofmemory/00000001/00000001 POSIX_FADV_NORMAL\""
fi
}
fadvise_inactive() {
if [ "${USE_FADVISE}" == "y" ]
then
echo "system \"/shared/linux-fadvise ${dir}/fileinmemory1/00000001/00000001 POSIX_FADV_WILLNEED\""
echo "system \"/shared/linux-fadvise ${dir}/fileinmemory2/00000001/00000001 POSIX_FADV_NORMAL\""
echo "system \"/shared/linux-fadvise ${dir}/fileoutofmemory/00000001/00000001 POSIX_FADV_NORMAL\""
fi
}
fmlock_init() {
LOCK_TIME=$1
if [ "${USE_FMLOCK}" == "y" ]
then
echo "system \"job /shared/linux-fmlock ${dir}/fileinmemory1/00000001/00000001 ${LOCK_TIME}\""
fi
}
fmlock() {
LOCK_TIME=$1
if [ "${USE_FMLOCK}" == "y" ]
then 
echo "system \"job /shared/linux-fmlock ${dir}/fileinmemory2/00000001/00000001 ${LOCK_TIME}\""
fi
}
