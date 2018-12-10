echo '
set $dir=/data/B/
set $filesize=2g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=bseqreader,instances=1
{
  thread name=bcold,memsize=$iosize,instances=1
  {
    flowop read name=seqread,filename=largefile,iosize=$iosize
  }
}

define process name=brandreader,instances=10
{
  thread name=bhot,memsize=$iosize,instances=1
  {
    flowop eventlimit name=limit
    flowop read name=randread,filename=largefile,iosize=$iosize,random,workingset=1g
  }
}

eventgen rate = 0
create files
'
