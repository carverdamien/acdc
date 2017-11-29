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
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/memory/consolidate ] || rmdir /rootfs/sys/fs/cgroup/memory/consolidate'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/memory/consolidate'
${PRE} exec host bash -c 'echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/memory.use_hierarchy'
${PRE} exec host bash -c "echo ${MEMORY} > /rootfs/sys/fs/cgroup/memory/consolidate/memory.limit_in_bytes"
${PRE} down

# Run
${RUN} create
${RUN} up -d
${RUN} exec sysbencha job run --dbsize ${DBSIZE} --duration 300
${RUN} exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 120
${RUN} exec cassandra job start
sleep 60
${RUN} exec cassandra job stop
sleep 60
${RUN} exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 60

# Report
for m in memory_stats blkio_stats networks cpu_stats sysbench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
