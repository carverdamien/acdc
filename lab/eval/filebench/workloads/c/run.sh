SLEEP=5
SHORT_CYCLE=12
LONG__CYCLE=48
LOW=0
MED=1024
MED=2048
source "$(dirname $0)/prepare.sh"
echo '
create processes
eventgen rate = 1
sleep 1
'
cycle() {
echo "eventgen rate = $2"
for i in $(seq $1)
do
cat <<EOF
stats clear
sleep ${SLEEP}
stats snap
EOF
done
}
cycle ${SHORT_CYCLE} $LOW
cycle ${SHORT_CYCLE} $LOW
cycle ${SHORT_CYCLE} $LOW
cycle ${LONG__CYCLE} $LOW #
cycle ${SHORT_CYCLE} $MED
cycle ${LONG__CYCLE} $LOW #
cycle ${SHORT_CYCLE} $LOW
cycle ${LONG__CYCLE} $LOW #
cycle ${SHORT_CYCLE} $MED
cycle ${LONG__CYCLE} $LOW #
cycle ${LONG__CYCLE} $LOW #
