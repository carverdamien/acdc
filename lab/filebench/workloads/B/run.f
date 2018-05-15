set $dir=/data/B
set $filesize=1g
set $iosize=1m
set $nthreads=1

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereader,instances=10
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop eventlimit name=limit
    flowop read name=seqread-file,filename=largefile,iosize=$iosize,directio
  }
}

eventgen rate = 0
create files
create processes
eventgen rate = 50
stats clear
sleep 10
stats snap
stats clear
sleep 10
stats snap
stats clear
eventgen rate = 150
sleep 1
eventgen rate = 50
sleep 9
stats snap
stats clear
sleep 10
stats snap
stats clear
sleep 10
stats snap
stats clear
sleep 10
stats snap
stats clear
eventgen rate = 150
sleep 1
eventgen rate = 50
sleep 9
stats snap
stats clear
sleep 10
stats snap
stats clear
sleep 10
stats snap
stats clear
sleep 10
stats snap
shutdown
