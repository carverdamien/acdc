#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=3800358912}

PRE="docker-compose --project-directory $PWD -f compose/$MODE/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/$MODE/restricted.yml"

case $MODE in
	standalone)
MYSQLB_HOST="mysqlb"
MYSQLB_DBNM="dbname"
;;
	isolated)
MYSQLB_HOST="mysqlb"
MYSQLB_DBNM="dbname"
;;
	process)
echo TODO
# gosu mysql mysqld --initialize-insecure --datadir=/var/lib/mysql/3307.data
# gosu mysql mysqld --datadir=/var/lib/mysql/3307.data --socket=/var/run/mysqld/3307.sock --port=3307
exit 1
;;
	not_isolated)
MYSQLB_HOST="mysqlb"
MYSQLB_DBNM="dbname2"
;;
	*)
echo "unknown MODE: ${MODE}"
	exit 1
		;;
esac

# Prepare
${RUN} down
${PRE} down
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec sysbencha prepare --dbsize ${DBSIZE}
${PRE} exec sysbenchb python benchmark.py --mysql-hostname ${MYSQLB_HOST} --mysql-dbname ${MYSQLB_DBNM} prepare --dbsize ${DBSIZE}
# ${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} down

# Run
${RUN} create
${RUN} up -d

MAXTXR=390                # Max on one core
MAXTXR=520
MAXTXR=585
MEDTXR=$((MAXTXR*45/100)) # Medium is 45%
LOWTXR=$((MAXTXR*10/100)) # Low is 10%
BRTTXR=$((MAXTXR*2))      # Extra requests on a second (burst)

TIMEA1=25 # Time A is medium
TIMEA2=10 # Time A is low
TIMEA3=15 # Time A is medium

TIMEB1=10 # Time B is medium
TIMEB2=20 # Time B is medium
TIMEB3=20 # Time B is medium

NA1=$((TIMEA1 * MEDTXR))
NA2=$((TIMEA2 * LOWTXR + NA1))
NA3=$((TIMEA3 * MEDTXR + NA2))

NB1=$((TIMEB1 * MEDTXR))
NB2=$((1 * BRTTXR + NB1))
NB3=$(( (TIMEB2-1) * MEDTXR + NB2))
NB4=$((1 * BRTTXR + NB3))
NB5=$(( (TIMEB3-1) * MEDTXR + NB4))

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate ${MEDTXR} --scheduled-rate=${MEDTXR},${LOWTXR},${MEDTXR}                     --scheduled-time=0,0,0     --scheduled-requests=${NA1},${NA2},${NA3}               --max-requests ${NA3} --num-threads=2;}
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 --mysql-hostname ${MYSQLB_HOST} --mysql-dbname ${MYSQLB_DBNM} run --dbsize ${DBSIZE} --tx-rate ${MEDTXR} --scheduled-rate=${MEDTXR},${BRTTXR},${MEDTXR},${BRTTXR},${MEDTXR} --scheduled-time=0,0,0,0,0 --scheduled-requests=${NB1},${NB2},${NB3},${NB4},${NB5} --max-requests ${NB5};}

A | tee A.out &
B | tee B.out &

wait
wait

# Report
mkdir -p data/$MODE
for m in memory_stats blkio_stats networks cpu_stats sysbench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$MODE/$m.csv
done
