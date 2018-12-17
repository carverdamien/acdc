id="$(basename $(readlink -e .))"
dir="/data/${id}/"
memory=$((2**30))
inmemory=$((memory*(64+16)/128))
outofmemory=$((2*memory))
iosize="1m"

echo "
define file name=fileinmemory,    path=${dir}, size=${inmemory},    prealloc, reuse
define file name=fileoutofmemory, path=${dir}, size=${outofmemory}, prealloc, reuse

# processB doit gener process A
define process name=process${id},instances=1
{
  thread name=${id}hot,memsize=${iosize},instances=1
  {
    # Si hotread{1,2} partage les fd de coldread{1,2},
    # alors il faut attendre que tout soit charger pour maximiser le throughput
    # Si hotread{1,2} ne partage pas les fd de coldread{1,2},
    # il finira par rejoindre coldread{1,2}
    # 
    # Il faut que thread hot puisse, en parallel de coldread{1,2}, charger fileinmemory
    #
    # flowop eventlimit name=limit1
    # flowop read name=hotread1, filename=fileinmemory, iosize=${iosize}, fd=3
    # flowop eventlimit name=limit2
    # flowop read name=hotread2, filename=fileinmemory, iosize=${iosize}, fd=4
    flowop eventlimit name=limit3
    flowop read random, name=hotread3, filename=fileinmemory, iosize=${iosize}, fd=6
  }
  # thread cold doit gener processA sans gener thread hot
  thread name=${id}cold,memsize=${iosize},instances=1
  {
    # coldread{1,2} prepare la memoire pour thread hot.
    # coldread{1,2} doit gener processA
    flowop read name=coldread1, filename=fileinmemory, iosize=${iosize}, fd=3
    flowop read name=coldread2, filename=fileinmemory, iosize=${iosize}, fd=4
    # coldread3 doit ralentir thread cold.
    # Double touch sur fileoutofmemory gene thread hot et l'empeche de charger fileinmemory
    flowop read name=coldread3, filename=fileoutofmemory, iosize=${iosize}, fd=5
  }
}

eventgen rate = 0
create files
"
