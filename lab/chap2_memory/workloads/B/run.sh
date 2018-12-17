#!/bin/bash
# Script that generates run.f

SLEEP_BEFORE_SPAWN="sleep 30"
SLEEP_BEFORE_SPAWN=""
SLEEP=2
LOW=0
MED=1024
HIG=$MED

# HIG=$((MED*1/2))
# HIG=$((MED*1/8))

schedule() {
# warmup $MED 10
phase $LOW 20
phase $HIG 1
phase $LOW 49
phase $HIG 1
phase $LOW 69
}

schedule() {
phase $LOW 20
phase $HIG 1
phase $LOW 39
phase $HIG 1
phase $LOW 49
}

cycle() { echo $1; }
# cycle() { echo $(( $1 / SLEEP )); }

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
CYCLE=$(cycle $2)
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
