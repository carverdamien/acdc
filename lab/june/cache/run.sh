#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]
MEMORY=$((2**31))

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"

# Prepare
make -C workloads
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec filebench filebencha -f workloads/a/prepare.f
${PRE} exec filebench filebenchb -f workloads/b/prepare.f
${PRE} exec filebench filebenchc -f workloads/c/prepare.f
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c 'echo cfq > /sys/block/sda/queue/scheduler'
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/memory/parent ] || rmdir /rootfs/sys/fs/cgroup/memory/parent'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/memory/parent'
${PRE} exec host bash -c 'echo 1 > /rootfs/sys/fs/cgroup/memory/parent/memory.use_hierarchy'
${PRE} exec host bash -c "echo ${MEMORY} > /rootfs/sys/fs/cgroup/memory/parent/memory.limit_in_bytes"
${PRE} down

# Run
${RUN} create
${RUN} up -d

RUN_A() { ${RUN} exec -T filebencha python benchmark.py -- filebench -f workloads/a/run.f;}
RUN_B() { ${RUN} exec -T filebenchb python benchmark.py -- filebench -f workloads/b/run.f;}
RUN_C() { ${RUN} exec -T filebenchc python benchmark.py -- filebench -f workloads/c/run.f;}

RUN_A &
RUN_B &
RUN_C &

wait
wait
wait

# Report
mkdir -p data
for m in memory_stats blkio_stats networks cpu_stats filebench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
