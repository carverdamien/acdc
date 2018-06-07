#!/bin/bash
set -x -e

[ -n "$KERNEL" ]
[ -n "$MEMORY" ]

[ "$(uname -sr)" == "Linux ${KERNEL}" ]

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"

# Prepare
DATA_DIR="data/$KERNEL/$MEMORY"
mkdir -p "$DATA_DIR"
make -C workloads
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec filebencha filebench -f workloads/a/prepare.f
${PRE} exec filebenchb filebench -f workloads/b/prepare.f
${PRE} exec filebenchc filebench -f workloads/c/prepare.f
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
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "$DATA_DIR/$m.csv"
done
