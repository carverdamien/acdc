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

    # flowop read name=evtread3, filename=fileinmemory, iosize=${smallio}, fd=5
    # flowop read name=evtread4, filename=fileinmemory, iosize=${smallio}, fd=6
    # flowop read name=evtread5, filename=fileinmemory, iosize=${smallio}, fd=7
    # flowop read name=evtread6, filename=fileinmemory, iosize=${smallio}, fd=8
    # flowop read name=evtread7, filename=fileinmemory, iosize=${smallio}, fd=9
    # flowop read name=evtread8, filename=fileinmemory, iosize=${smallio}, fd=10
    # flowop read name=evtread9, filename=fileinmemory, iosize=${smallio}, fd=11
    # flowop read name=evtread10, filename=fileinmemory, iosize=${smallio}, fd=12
    # flowop read name=evtread11, filename=fileinmemory, iosize=${smallio}, fd=13
    #flowop read name=evtread12, filename=fileinmemory, iosize=${smallio}, fd=14
  }
  # We have no control over always thread
  thread name=${id}alw,memsize=${bigio},instances=1
  {
    # alw thread must help evt thread
    flowop read name=alwread1, filename=fileinmemory,    iosize=${bigio}, fd=15

    # alw thread must be slowed with a fileoutofmemory
    flowop read name=alwread2, filename=fileoutofmemory, iosize=${smallio}, fd=16
  }
}

eventgen rate = 0
create files
"
