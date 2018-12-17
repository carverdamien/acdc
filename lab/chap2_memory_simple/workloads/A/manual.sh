#!/bin/bash
# Script that generates run.f

SLEEP_BEFORE_SPAWN=""
SLEEP=5
LOW=10
MED=1024

# DEBUG
SLEEP=2
LOW=0

lowmem(){
# echo "system \"bash '-c' 'echo -1 > /sys/fs/cgroup/memory/memory.force_empty'\""
echo "system \"bash '-c' 'until echo $((2**30/2**4)) > /sys/fs/cgroup/memory/memory.usage_in_bytes'; do :; done\""
}
highmem(){
echo "system \"bash '-c' 'echo $((2**30)) > /sys/fs/cgroup/memory/memory.usage_in_bytes'\""
}

schedule() {
# warmup $MED 10
highmem
phase $MED 80
lowmem
phase $LOW 20
highmem
phase $MED 70
}

main() {
source prepare.sh
echo "
${SLEEP_BEFORE_SPAWN}
create processes
eventgen rate = 1
sleep 1
"
schedule
echo 'shutdown'
}

phase() {
RATE=$1
CYCLE=$2
echo "eventgen rate = ${RATE}"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
}

warmup() {
RATE=$1
CYCLE=$2
echo "eventgen rate = ${RATE}"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats clear
EOF
done
}

main
