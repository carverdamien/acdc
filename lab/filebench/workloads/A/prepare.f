set $dir=/data/A/
set $filesize=1g
set $iosize=1m
set $nthreads=1

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop read name=seqread-file,filename=largefile,iosize=$iosize,directio
  }
}

create files
