echo '
set $dir=/data/A/
set $filesize=1g
set $iosize=1m

set $GB=1073741824
set $MB=1048576
set $KB=1024

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=cold,memsize=2m,instances=1
  {
    flowop read name=seqread,filename=largefile,iosize=$iosize,random
  }
  thread name=hot,memsize=512m,instances=1
  {
    flowop eventlimit name=limit
    flowop hog name=hot,value=131072,workingset=512m,iosize=4k
  }
}

create files
'
