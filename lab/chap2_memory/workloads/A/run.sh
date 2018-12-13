#!/bin/bash
# Script that generates run.f

SLEEP_BEFORE_SPAWN=""
SLEEP=5
LOW=10
MED=1024

# DEBUG
SLEEP=2
LOW=0

schedule() {
# warmup $MED 10
phase $MED 80
phase $LOW 20
phase $MED 40
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
