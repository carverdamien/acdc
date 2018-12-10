set $dir=/data/A/
set $filesize=1g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=2m,instances=1
  {
    flowop eventlimit name=limit
    flowop read name=seqread-file,filename=largefile,iosize=$iosize
  }
}

eventgen rate = 0
create files
