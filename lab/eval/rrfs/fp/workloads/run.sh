CYCLE=60
LOW=0
MED=100
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
sleep 1
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $LOW"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo 'shutdown'
