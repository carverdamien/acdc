id="$(basename $(readlink -e .))"
dir="/data/${id}/"
memory=$((2**30))
inmemory=$((memory*(64+16)/128))
outofmemory=$((2*memory))
iosize="1m"

echo "
define file name=fileinmemory,    path=${dir}, size=${inmemory},    prealloc, reuse
define file name=fileoutofmemory, path=${dir}, size=${outofmemory}, prealloc, reuse

define process name=process${id},instances=1
{
  thread name=${id}hot,memsize=${iosize},instances=1
  {
    # 'Pas de random' et 'Pas de double touch' devrait assurer que le throughput ne soit pas maximal
    # tant que tout n'est pas charge.
    #
    # Partage de fd=3 entre hotread1 et coldread1 devrait assurer que
    # le deuxieme acces n'arrive que lorsque tout est charge
    #
    flowop eventlimit name=limit1
    flowop read name=hotread1, filename=fileinmemory, iosize=${iosize}, fd=3
  }
  thread name=${id}cold,memsize=${iosize},instances=1
  {
    # Pas de double touch sur fileinmemory.
    # coldread1 et hotread1 travail sur fileinmemory alors que coldread2 travail sur fileoutofmemory.
    # Il y a donc deux fois plus de bande passante disque consacree a fileinmemory.
    # Cela devrait garantir que fileinmemory finisse par tenir en memoire.
    #
    flowop read name=coldread1, filename=fileinmemory,    iosize=${iosize}, fd=3
    # coldread2 ralentit thread cold
    #
    flowop read name=coldread2, filename=fileoutofmemory, iosize=${iosize}, fd=4
  }
}

eventgen rate = 0
create files
"
