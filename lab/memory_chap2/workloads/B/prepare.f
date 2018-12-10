set $dir=/data/B
set $filesize=1g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereaderB,instances=1
{
  thread name=filereaderthreadB1,memsize=2m,instances=1
  {
    flowop eventlimit name=limit
    flowop read name=seqread-file,filename=largefile,iosize=$iosize,directio
  }
}

eventgen rate = 0
create files
