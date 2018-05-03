#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=3800358912}

RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"
PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"

# Prepare
${RUN} down
${PRE} down
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec sysbencha prepare --dbsize ${DBSIZE}
${PRE} exec sysbenchb prepare --dbsize ${DBSIZE}
${PRE} exec sysbenchc prepare --dbsize ${DBSIZE}
# ${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c 'echo cfq | tee /sys/block/sda/queue/scheduler'
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/blkio/consolidate ] || find /rootfs/sys/fs/cgroup/blkio/consolidate -type d -delete'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/blkio/consolidate'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/blkio/consolidate/B'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/blkio/consolidate/C'
${PRE} exec host bash -c 'echo $(cat /sys/block/sda/dev) $((2**20)) > /rootfs/sys/fs/cgroup/blkio/consolidate/blkio.throttle.read_bps_device'
${PRE} exec host bash -c 'echo 1000 > /rootfs/sys/fs/cgroup/blkio/consolidate/blkio.weight'
${PRE} exec host bash -c 'echo 1000 > /rootfs/sys/fs/cgroup/blkio/consolidate/blkio.leaf_weight'
${PRE} exec host bash -c 'echo 10 > /rootfs/sys/fs/cgroup/blkio/consolidate/B/blkio.weight'
${PRE} exec host bash -c 'echo 10 > /rootfs/sys/fs/cgroup/blkio/consolidate/C/blkio.weight'
${PRE} down

MAXTXR=870
MAXTXR=770
MAXTXR=780
MAXTXR=781
CYCLE=10

# Run
${RUN} create
${RUN} up -d

SCHED() {
	X=$1
	shift
	NREQ=0	
	TXRATE=$((MAXTXR * X / 100))
	NREQ=$((TXRATE * CYCLE + NREQ))
	CMD="--tx-rate ${TXRATE}"
	RATE="--scheduled-rate=${TXRATE}"
	TIME="--scheduled-time=0"
	REQT="--scheduled-requests=${NREQ}"

	for X in $@
	do
		TXRATE=$((MAXTXR * X / 100))
		NREQ=$((TXRATE * CYCLE + NREQ))
		RATE="${RATE},${TXRATE}"
		TIME="${TIME},0"
		REQT="${REQT},${NREQ}"
	done
	echo "${CMD} ${RATE} ${TIME} ${REQT} --max-requests ${NREQ}"
}

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} $(SCHED 25 50 25 25 100 25 25 25 25 25 50 25 25 25 50 25 50 25 25 25);}
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 run --dbsize ${DBSIZE} $(SCHED 25 25 50 25 25 25 100 25 25 25 50 25 50 25 25 25 50 25 25 25);}
C() { ${RUN} exec -T sysbenchc python benchmark.py --wait=0 run --dbsize ${DBSIZE} $(SCHED 25 25 25 50 25 25 25 25 100 25 25 25 50 25 50 25 50 25 25 25);}


A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate=0 --duration=60; }
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate=0 --duration=60; }
C() { ${RUN} exec -T sysbenchc python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate=0 --duration=60; }

A | tee A.out &
B | tee B.out &
C | tee C.out &

wait
wait
wait

# Report
for m in memory_stats blkio_stats networks cpu_stats sysbench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
