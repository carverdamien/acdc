#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]
[ -n "${SLEEP}" ]

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"

# Prepare
make -C workloads
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec filebench filebench -f workloads/prepare.f
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c 'echo cfq > /sys/block/sda/queue/scheduler'
${PRE} down

# Run
${RUN} create
${RUN} up -d

# Get container id
filebench=$(${RUN} ps -q filebench)

# Start scanner
${RUN} exec scanner job scan /rootfs/sys/fs/cgroup/memory/docker/${filebench} $((2**20)) ${SLEEP}

RUN() { ${RUN} exec -T filebench python benchmark.py -- filebench -f workloads/run.f;}

RUN &

wait

# Report
mkdir -p data/$SLEEP
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$SLEEP/$m.csv
done
