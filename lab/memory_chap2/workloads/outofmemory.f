set $dir=/data/outmemory
set $iosize=1m

define file name=coldfile1,path=$dir/files,size=5g,reuse,prealloc
define file name=coldfile2,path=$dir/files,size=5g,reuse,prealloc

# 8 hit for 2 miss

define process name=p2-a1,instances=1
{
thread name=access1, memsize=1m, instances=1
{
flowop semblock name=semblock1, value=1, highwater=1
flowop read name=readfile1,fd=1,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost1, target=semblock1done, value=1
flowop sempost name=sempost1, target=semblock2, value=1
}
}
define process name=p2-a2,instances=1
{
thread name=access2, memsize=1m, instances=1
{
flowop semblock name=semblock2, value=1, highwater=1
flowop read name=readfile2,fd=2,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost2, target=semblock3, value=1
}
}
define process name=p2-a3,instances=1
{
thread name=access3, memsize=1m, instances=1
{
flowop semblock name=semblock3, value=1, highwater=1
flowop read name=readfile3,fd=3,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost3, target=semblock4, value=1
}
}
define process name=p2-a4,instances=1
{
thread name=access4, memsize=1m, instances=1
{
flowop semblock name=semblock4, value=1, highwater=1
flowop read name=readfile4,fd=4,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost4, target=semblock5, value=1
}
}
define process name=p2-a5,instances=1
{
thread name=access5, memsize=1m, instances=1
{
flowop semblock name=semblock5, value=1, highwater=1
flowop read name=readfile5,fd=5,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost5, target=semblock6, value=1
}
}
define process name=p2-a6,instances=1
{
thread name=access6, memsize=1m, instances=1
{
flowop semblock name=semblock6, value=1, highwater=1
flowop read name=readfile6,fd=6,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost6, target=semblock7, value=1
}
}
define process name=p2-a7,instances=1
{
thread name=access7, memsize=1m, instances=1
{
flowop semblock name=semblock7, value=1, highwater=1
flowop read name=readfile7,fd=7,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost7, target=semblock8, value=1
}
}
define process name=p2-a8,instances=1
{
thread name=access8, memsize=1m, instances=1
{
flowop semblock name=semblock8, value=1, highwater=1
flowop read name=readfile8,fd=8,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost8, target=semblock9, value=1
}
}
define process name=p2-a9,instances=1
{
thread name=access9, memsize=1m, instances=1
{
flowop semblock name=semblock9, value=1, highwater=1
flowop read name=readfile9,fd=9,iosize=$iosize,filename=coldfile1
flowop sempost name=sempost9, target=semblock10, value=1
}
}
define process name=p2-aT,instances=1
{
thread name=thrashAccess, memsize=1m, instances=1
{
flowop eventlimit name=eventlimit
flowop sempost name=thrashsempost, target=semblock1, value=1
flowop semblock name=semblock1done, value=1, highwater=1
flowop read name=trash, filename=coldfile2, iosize=$iosize, fd=18
flowop semblock name=semblock10, value=1, highwater=1
}
}
