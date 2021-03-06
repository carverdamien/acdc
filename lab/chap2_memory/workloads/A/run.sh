#!/bin/bash
# Script that generates run.f
set -e

SLEEP_BEFORE_SPAWN=""
: ${TIME_SCALE:=2}
LOW=0
MED=1024
MED=$((MED*3))

schedule() {
fmlock_init $((110 * TIME_SCALE))
fadvise_active
fmlock $((50 * TIME_SCALE))
phase $MED 50
fadvise_inactive
phase $LOW 30
fadvise_active
fmlock $((30 * TIME_SCALE))
phase $MED 30
}

main() {
check
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
sleep ${TIME_SCALE}
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
sleep ${TIME_SCALE}
stats clear
EOF
done
}

check() {
[ ${TIME_SCALE} -gt 1 ]
}

main
