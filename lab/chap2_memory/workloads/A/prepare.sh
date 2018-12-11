id="$(basename $(readlink -e .))"
dir="/data/${id}/"
filesize="2g"
iosize="1m"
echo "
define file name=largefile,path=${dir},size=${filesize},prealloc,reuse

define process name=${id}coldreader,instances=1
{
  thread name=${id}cold,memsize=${iosize},instances=1
  {
    flowop read name=coldread,filename=largefile,iosize=${iosize},random
  }
}

define process name=${id}hotreader,instances=10
{
  thread name=${id}hot,memsize=${iosize},instances=1
  {
    flowop eventlimit name=limit
    flowop read name=hotread,filename=largefile,iosize=${iosize},random,workingset=1g
  }
}

eventgen rate = 0
create files
"
