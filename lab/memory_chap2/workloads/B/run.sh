#!/bin/bash
# Script that produces run.f

MED=100
HIG=$((500*5))

schedule() {
phase $MED 30
phase $HIG 1
phase $MED 39
phase $HIG 1
phase $MED 39
# TOTAL 110
}

### END OF CONFIG ###

main() {
cat prepare.f
echo 'create processes'
schedule
echo 'shutdown'
}

phase() {
RATE=$1
REPEAT=$2
echo "eventgen rate = ${RATE}"
for i in $(seq ${REPEAT})
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
}

main
