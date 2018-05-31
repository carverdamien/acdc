#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]
[ -n "${SCAN}" ]

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

# Start ftrace
DATA_DIR=data/$SCAN
mkdir -p ${DATA_DIR}
TRACE_DAT=/data/${SCAN}/trace.dat
${RUN} exec host rm -f ${TRACE_DAT}*
${RUN} exec -T host job trace-cmd record -p function_graph -l scan_mem_cgroup_pages -g scan_mem_cgroup_pages -o ${TRACE_DAT}

# Get container id
filebench=$(${RUN} ps -q filebench)

# Start scanner
${RUN} exec scanner job scan /rootfs/sys/fs/cgroup/memory/docker/${filebench} ${SCAN} 1

RUN() { ${RUN} exec -T filebench python benchmark.py -- filebench -f workloads/run.f;}

RUN &

wait

# Stop ftrace
${RUN} exec host bash -c 'kill -s SIGINT $(pgrep trace-cmd)'
while ${RUN} exec host pgrep trace-cmd; do echo 'waiting'; sleep 1; done

# Report
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > ${DATA_DIR}/$m.csv
done
