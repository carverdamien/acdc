#!/bin/bash
# Script that generates run.f

SLEEP=5
LOW=1
MED=1024
HIG=$((MED*2))

# DEBUG
SLEEP=2

schedule() {
warmup $MED 10
phase $LOW 20
phase $HIG 1
phase $LOW 39
phase $HIG 1
phase $LOW 39
}

main() {
source prepare.sh
echo '
create processes
eventgen rate = 1
sleep 1
'
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