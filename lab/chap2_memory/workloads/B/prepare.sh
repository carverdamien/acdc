echo '
set $dir=/data/B/
set $filesize=2g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=bcoldreader,instances=1
{
  thread name=bcold,memsize=$iosize,instances=1
  {
    flowop read name=coldread,filename=largefile,iosize=$iosize,random
  }
}

define process name=bhotreader,instances=10
{
  thread name=bhot,memsize=$iosize,instances=1
  {
    flowop eventlimit name=limit
    flowop read name=hotread,filename=largefile,iosize=$iosize,random,workingset=1g
  }
}

eventgen rate = 0
create files
'
