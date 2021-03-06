#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${SCALE:=1}
: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=3800358912}
: ${BLKIO:=$((50*2**20))}

PRE="docker-compose --project-directory $PWD -f compose/$MODE/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/$MODE/restricted.yml"

case $MODE in
	Aonly)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3306"
MYSQLB_DBNM="dbname"
;;
	Bonly)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3306"
MYSQLB_DBNM="dbname"
;;
	standalone)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3306"
MYSQLB_DBNM="dbname"
;;
	isolated)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3306"
MYSQLB_DBNM="dbname"
;;
	noshares)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3306"
MYSQLB_DBNM="dbname"
;;
	process)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3307"
MYSQLB_DBNM="dbname"
;;
	not_isolated)
MYSQLB_HOST="mysqlb"
MYSQLB_PORT="3306"
MYSQLB_DBNM="dbname2"
;;
	*)
echo "unknown MODE: ${MODE}"
	exit 1
		;;
esac

start_mysqlb() {
case ${MODE} in
	process)
${PRE} exec mysqla gosu mysql mysqld --initialize-insecure --datadir=/var/lib/3307.data || true
${PRE} exec -d mysqla gosu mysql mysqld --datadir=/var/lib/3307.data --socket=/var/run/mysqld/3307.sock --port=3307
;;
esac
}

# Prepare
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec sysbencha prepare --dbsize ${DBSIZE}
start_mysqlb
${PRE} exec sysbenchb python benchmark.py --mysql-hostname ${MYSQLB_HOST} --mysql-port ${MYSQLB_PORT} --mysql-dbname ${MYSQLB_DBNM} prepare --dbsize ${DBSIZE}
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c 'echo cfq > /sys/block/sda/queue/scheduler'
#${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/blkio/consolidate ] || rmdir /rootfs/sys/fs/cgroup/blkio/consolidate'
#${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/blkio/consolidate'
#${PRE} exec host bash -c "echo '$(cat /sys/block/sda/dev) ${BLKIO}' > /rootfs/sys/fs/cgroup/blkio/consolidate/blkio.throttle.read_bps_device"
${PRE} down

# Run
${RUN} create
${RUN} up -d
start_mysqlb

MAXTXR=390                # Max on one core
MAXTXR=520
MAXTXR=585
MAXTXR=600
MAXTXR=1300
MAXTXR=1400
MAXTXR=1600
MEDTXR=$((MAXTXR*40/2/100)) # Medium is 40%
LOWTXR=$((MAXTXR*10/2/100)) # Low is 10%
BRTTXR=$((MAXTXR*2*2))      # Extra requests on a second (burst)

INIT=20

TIMEA1=$((INIT + 25 * SCALE)) # Time A is medium
TIMEA2=$((10 * SCALE)) # Time A is low
TIMEA3=$((15 * SCALE)) # Time A is medium

TIMEB1=$((INIT + 10 * SCALE)) # Time B is medium
TIMEB2=$((20 * SCALE)) # Time B is medium
TIMEB3=$((20 * SCALE)) # Time B is medium

NA1=$((TIMEA1 * MEDTXR))
NA2=$((TIMEA2 * LOWTXR + NA1))
NA3=$((TIMEA3 * MEDTXR + NA2))

NB1=$((TIMEB1 * MEDTXR))
NB2=$((1 * BRTTXR + NB1))
NB3=$(( (TIMEB2-1) * MEDTXR + NB2))
NB4=$((1 * BRTTXR + NB3))
NB5=$(( (TIMEB3-1) * MEDTXR + NB4))

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate ${MEDTXR} --scheduled-rate=${MEDTXR},${LOWTXR},${MEDTXR}                     --scheduled-time=0,0,0     --scheduled-requests=${NA1},${NA2},${NA3}               --max-requests ${NA3} --num-threads=2;}
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 --mysql-hostname ${MYSQLB_HOST} --mysql-port ${MYSQLB_PORT} --mysql-dbname ${MYSQLB_DBNM} run --dbsize ${DBSIZE} --tx-rate ${MEDTXR} --scheduled-rate=${MEDTXR},${BRTTXR},${MEDTXR},${BRTTXR},${MEDTXR} --scheduled-time=0,0,0,0,0 --scheduled-requests=${NB1},${NB2},${NB3},${NB4},${NB5} --max-requests ${NB5} --num-threads=16;}

# Test Max Trps
# A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate 0 --duration 60 --num-threads=8;}
# B() { :;}

[ $MODE == Bonly ] || A | tee A.out &
[ $MODE == Aonly ] || B | tee B.out &

wait
wait

# Report
mkdir -p data/$MODE
for m in memory_stats blkio_stats networks cpu_stats sysbench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$MODE/$m.csv
done
