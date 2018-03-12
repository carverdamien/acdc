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
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/cpu/consolidate ] || find /rootfs/sys/fs/cgroup/cpu/consolidate -type d -delete'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/A'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/BC'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/BC/B'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/cpu/consolidate/BC/C'
${PRE} exec host bash -c 'echo 100000 > /rootfs/sys/fs/cgroup/cpu/consolidate/cpu.cfs_period_us'
${PRE} exec host bash -c 'echo 100000 > /rootfs/sys/fs/cgroup/cpu/consolidate/cpu.cfs_quota_us'
${PRE} exec host bash -c 'echo 1024 > /rootfs/sys/fs/cgroup/cpu/consolidate/A/cpu.shares'
${PRE} exec host bash -c 'echo 2 > /rootfs/sys/fs/cgroup/cpu/consolidate/BC/cpu.shares'
${PRE} exec host bash -c 'echo 1024 > /rootfs/sys/fs/cgroup/cpu/consolidate/BC/B/cpu.shares'
${PRE} exec host bash -c 'echo 2 > /rootfs/sys/fs/cgroup/cpu/consolidate/BC/C/cpu.shares'
${PRE} down

# Run
${RUN} create
${RUN} up -d
${RUN} exec sysbencha job run --dbsize ${DBSIZE} --duration 200 --tx-rate 600
${RUN} exec sysbenchb job run --dbsize ${DBSIZE} --duration 200 --tx-rate 600
${RUN} exec sysbenchc job run --dbsize ${DBSIZE} --duration 200 --tx-rate 600
sleep 200

# Report
for m in memory_stats blkio_stats networks cpu_stats sysbench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
