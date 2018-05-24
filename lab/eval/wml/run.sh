LOW=50
MED=100
source prepare.sh
echo '
eventgen rate = 0
create processes
'
echo "eventgen rate = $MED"
for i in {1..60}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $LOW"
for i in {1..20}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo "eventgen rate = $MED"
for i in {1..30}
do
cat <<EOF
stats clear
sleep 1
stats snap
EOF
done
echo 'shutdown'
