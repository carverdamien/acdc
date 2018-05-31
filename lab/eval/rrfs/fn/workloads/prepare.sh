echo '
set $dir=/data/A/
set $filesize=1g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=hot,memsize=$iosize,instances=1
  {
    flowop eventlimit name=limit
    flowop read name=randread,filename=largefile,iosize=$iosize,random,workingset=1g
  }
}

create files
'
