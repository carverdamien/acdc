echo '
set $dir=/data/A/
set $filesize=2g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=hot,memsize=2m,instances=100
  {
    flowop read name=randread,filename=largefile,iosize=$iosize,random,workingset=768m
  }
  thread name=cold,memsize=2m,instances=100
  {
    flowop eventlimit name=limit
    flowop read name=seqread,filename=largefile,iosize=$iosize
  }
}

create files
'
