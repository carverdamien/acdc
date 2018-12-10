MED=100
HIG=$((500*5))
echo '
set $dir=/data/B
set $filesize=1g
set $iosize=1m
set $nthreads=1

define file name=largefile,path=$dir,size=$filesize,prealloc,reuse

define process name=filereaderB,instances=100
{
  thread name=filereaderthreadB1,memsize=2m,instances=$nthreads
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
for i in {1..30}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $HIG"
for i in 1
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in {1..9}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
for i in {1..30}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $HIG"
for i in 1
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in {1..9}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
for i in {1..30}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo 'shutdown'
