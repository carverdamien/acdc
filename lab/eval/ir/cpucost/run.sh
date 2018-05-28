#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]
[ -n "${IDLEMEMSTAT_DELAY}" ]

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"

echo 'IDLEMEMSTAT_DELAY=${IDLEMEMSTAT_DELAY}' > .env

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

RUN() { ${RUN} exec -T filebench python benchmark.py -- filebench -f workloads/run.f;}

RUN &

wait

# Report
mkdir -p data/${IDLEMEMSTAT_DELAY}
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/${IDLEMEMSTAT_DELAY}/$m.csv
done
