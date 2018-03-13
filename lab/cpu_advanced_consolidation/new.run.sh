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
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/cpu/consolidate ] || find /rootfs/sys/fs/cgroup/cpu/consolidate -type d -delete'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/A'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/BC'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/BC/B'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/BC/C'
${PRE} exec host bash -c 'echo 1000000 > /rootfs/sys/fs/cgroup/cpu/consolidate/cpu.cfs_period_us'
${PRE} exec host bash -c 'echo 2000000 > /rootfs/sys/fs/cgroup/cpu/consolidate/cpu.cfs_quota_us'
${PRE} exec host bash -c 'echo 1024 > /rootfs/sys/fs/cgroup/cpu/consolidate/A/cpu.shares'
${PRE} exec host bash -c 'echo 2 > /rootfs/sys/fs/cgroup/cpu/consolidate/BC/cpu.shares'
${PRE} exec host bash -c 'echo 1024 > /rootfs/sys/fs/cgroup/cpu/consolidate/BC/B/cpu.shares'
${PRE} exec host bash -c 'echo 1024 > /rootfs/sys/fs/cgroup/cpu/consolidate/BC/C/cpu.shares'
${PRE} down

MAXTXR=800 # If too high, queues will fill to quickly
CYCLE=30 # If too long, queues will overflow

# Run
${RUN} create
${RUN} up -d

SCHED() {
	X=$1
	shift
	NREQ=0
	TXRATE=$((MAXTXR * X / 10))
	NREQ=$((TXRATE * CYCLE + NREQ))
	CMD="--tx-rate ${TXRATE} --max-requests ${NREQ}"
	RATE=""
	TIME=""
	REQT=""
	if [ -n "$1" ]
	then
		X=$1
		shift
		TXRATE=$((MAXTXR * X / 10))
		NREQ=$((TXRATE * CYCLE + NREQ))
		RATE="--scheduled-tx-rate=${TXRATE}"
		TIME="--scheduled-max-time=0"
		REQT="--scheduled-max-requests=${NREQ}"
	fi
	for X in $@
	do
		TXRATE=$((MAXTXR * X / 10))
		NREQ=$((TXRATE * CYCLE + NREQ))
		RATE="${RATE},${TXRATE}"
		TIME="${TIME},0"
		REQT="${REQT},${NREQ}"
	done
	echo "${CMD} ${RATE} ${TIME} ${REQT}"
}

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} $(SCHED 1 1 2 4 8 4 2 1 1);}
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 run --dbsize ${DBSIZE} $(SCHED 2 4 8 4 2 1 1 1 1);}
C() { ${RUN} exec -T sysbenchc python benchmark.py --wait=0 run --dbsize ${DBSIZE} $(SCHED 1 1 1 1 2 4 8 4 2);}

A&
B&
C&

wait
wait
wait

# Report
for m in memory_stats blkio_stats networks cpu_stats sysbench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
