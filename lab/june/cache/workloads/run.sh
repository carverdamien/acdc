SLEEP=5
CYCLE=12
LOW=0
MED=1024
source prepare.sh
echo '
create processes
eventgen rate = 1
sleep 1
'
echo "eventgen rate = $LOW"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
echo "eventgen rate = $LOW"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
echo 'shutdown'
