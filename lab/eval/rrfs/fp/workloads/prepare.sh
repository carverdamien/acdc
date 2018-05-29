echo '
set $dir=/data/A/
set $filesize=2g
set $iosize=1m

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse
define file name=smallfile,path=$dir,size=768m,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=hot,memsize=2m,instances=1
  {
    flowop semblock name=starthot,value=1
    flowop read name=randread,filename=smallfile,iosize=$iosize
    flowop sempost name=poststarthot,value=1,target=starthot
  }
  thread name=cold,memsize=2m,instances=1
  {
    flowop read name=seqread,filename=largefile,iosize=$iosize,iters=28800
    flowop readwholefile name=readwhole,filename=smallfile,iosize=$iosize
    flowop sempost name=poststarthot,target=starthot,value=1
    flowop semblock name=colddone
  }
}

create files
'
