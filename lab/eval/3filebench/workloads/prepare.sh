echo "
set \$dir=/data/
set \$smallfilesize=$((MEM/2))
set \$largefilesize=$((2*MEM))
set \$iosize=1m

define file name=largefile,path=\$dir,size=\$largefilesize,prealloc,reuse
define file name=smallfile,path=\$dir,size=\$smallfilesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=cold,memsize=\$iosize,instances=1
  {
    flowop read name=seqread,filename=largefile,iosize=\$iosize
  }
  thread name=hot,memsize=\$iosize,instances=10
  {
    flowop eventlimit name=limit
    flowop read name=randread,filename=smallfile,iosize=\$iosize,random
  }
}

create files
"
