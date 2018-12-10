LOW=50
MED=100
echo '
set $dir=/data/A/
set $filesize=1g
set $iosize=1m
set $nthreads=1

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereaderA,instances=2
{
  thread name=filereaderthreadA,memsize=2m,instances=$nthreads
  {
    flowop eventlimit name=limit
    flowop read name=seqread-file,filename=largefile,iosize=$iosize,directio
  }
}

eventgen rate = 0
create files
create processes
'
echo "eventgen rate = $MED"
for i in {1..60}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $LOW"
for i in {1..20}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in {1..30}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo 'shutdown'
