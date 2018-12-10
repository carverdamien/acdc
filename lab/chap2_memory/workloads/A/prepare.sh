echo '
set $dir=/data/A/
set $filesize=2g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=acoldreader,instances=1
{
  thread name=acold,memsize=$iosize,instances=1
  {
    flowop read name=coldread,filename=largefile,iosize=$iosize,random
  }
}

define process name=ahotreader,instances=10
{
  thread name=ahot,memsize=$iosize,instances=1
  {
    flowop eventlimit name=limit
    flowop read name=hotread,filename=largefile,iosize=$iosize,random,workingset=1g
  }
}

eventgen rate = 0
create files
'
