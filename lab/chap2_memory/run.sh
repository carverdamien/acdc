#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"

# Prepare
make -C workloads/A
make -C workloads/B
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec filebencha filebench -f workloads/A/prepare.f
${PRE} exec filebenchb filebench -f workloads/B/prepare.f
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c 'echo cfq > /sys/block/sda/queue/scheduler'
${PRE} down

# Run
${RUN} create
${RUN} up -d

RUNA() { ${RUN} exec -T filebencha python benchmark.py -- filebench -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb python benchmark.py -- filebench -f workloads/B/run.f;}

RUNA | tee A.out &
RUNB | tee B.out &

wait

# Report
mkdir -p data
for m in memory_stats blkio_stats networks cpu_stats filebench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
