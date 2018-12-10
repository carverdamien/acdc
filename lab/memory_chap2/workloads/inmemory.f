set $dir=/data/inmemory
set $iosize=1m

define file name=hotfile,path=$dir,size=1g,reuse,prealloc
define file name=coldfile,path=$dir,size=5g,reuse,prealloc

# 16 hit for 2 seq miss

define process name=process1, instances=1
{
thread name=HotThread, memsize=1m, instances=1
{
flowop semblock name=hotsemblock, value=1, highwater=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop read name=hot, filename=hotfile, iosize=$iosize, fd=1
flowop sempost name=hotsempost, target=hotsemblockdone, value=1
}
thread name=ColdThread, memsize=1m, instances=1
{
flowop eventlimit name=eventlimit
flowop read name=cold, filename=coldfile, iosize=$iosize, fd=2
flowop read name=cold, filename=coldfile, iosize=$iosize, fd=2
flowop sempost name=coldsempost, target=hotsemblock, value=1
flowop semblock name=hotsemblockdone, value=1, highwater=1
}
}
