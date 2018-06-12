SLEEP=5
CYCLE=12
LOW=0
MED=1024
source "$(dirname $0)/prepare.sh"
echo '
create processes
eventgen rate = 1
sleep 1
'
cycle() {
echo "eventgen rate = $1"
for i in $(seq ${CYCLE})
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
}
cycle $LOW
cycle $MED
cycle $LOW
cycle $LOW
cycle $LOW
cycle $MED
cycle $LOW
cycle $MED
cycle $LOW
cycle $MED
cycle $MED
cycle $LOW
cycle $LOW
