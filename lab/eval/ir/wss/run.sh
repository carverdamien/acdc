#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]
[ -n "${IDLEMEMSTAT_CPU_LIMIT}" ]
IDLEMEMSTAT_DELAY=0
IDLEMEMSTAT_SCAN_CHUNK=$((8*2**30/(4*2**10)))
IDLEMEMSTAT_SCAN_CHUNK=32768

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
sed "s/\${IDLEMEMSTAT_CPU_LIMIT}/${IDLEMEMSTAT_CPU_LIMIT}/" compose/restricted.yml > compose/.restricted.yml
RUN="docker-compose --project-directory $PWD -f compose/.restricted.yml"

echo "IDLEMEMSTAT_DELAY=${IDLEMEMSTAT_DELAY}
IDLEMEMSTAT_SCAN_CHUNK=${IDLEMEMSTAT_SCAN_CHUNK}
IDLEMEMSTAT_CPU_LIMIT=${IDLEMEMSTAT_CPU_LIMIT}" > .env

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

DATA_DIR=data/${IDLEMEMSTAT_CPU_LIMIT}
mkdir -p ${DATA_DIR}

# Start ftrace
#${RUN} exec host rm -f /${DATA_DIR}/trace.dat*
#${RUN} exec -T host job trace-cmd record -p function_graph -l page_idle_bitmap_read -l page_idle_bitmap_write -g page_idle_bitmap_read -g page_idle_bitmap_write -o /${DATA_DIR}/trace.dat

RUN() { ${RUN} exec -T filebench python benchmark.py -- filebench -f workloads/run.f;}

RUN &

wait

# Stop ftrace
#${RUN} exec host bash -c 'kill -s SIGINT $(pgrep trace-cmd)'
#while ${RUN} exec host pgrep trace-cmd; do echo 'waiting'; sleep 1; done

# Report
for m in  $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > ${DATA_DIR}/$m.csv
done
