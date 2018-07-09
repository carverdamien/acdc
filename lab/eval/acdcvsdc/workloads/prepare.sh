echo "
set \$dir=/data/
set \$smallfilesize=$(( 90*MEM/100 ))
set \$largefilesize=$(( 8*2**20 ))
set \$iosize=1m

define file name=largefile,path=\$dir,size=\$largefilesize,prealloc,reuse
define file name=smallfile,path=\$dir,size=\$smallfilesize,prealloc,reuse

define process name=filereader,instances=1
{
  thread name=cold,memsize=\$iosize,instances=1
  {
    flowop read name=seqread,filename=largefile,iosize=\$iosize
  }
  thread name=hot,memsize=\$iosize,instances=1
  {
    flowop read name=randread,filename=smallfile,iosize=\$iosize,random
  }
}
"
echo create files

