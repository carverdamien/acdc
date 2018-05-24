CYCLE=20
LOW=0
MED=1024
source prepare.sh
echo '
eventgen rate = 0
create processes
'
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
