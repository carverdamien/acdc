#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

PRE="docker-compose --project-directory $PWD -f compose/$MODE/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/$MODE/restricted.yml"

case $MODE in
	Aonly)
	echo "TODO"
	exit 1
;;
	Bonly)
	echo "TODO"
	exit 1
;;
	isolatedless)
	echo "TODO"
	exit 1
;;
	isolatedmore)
	echo "TODO"
	exit 1
;;
	process)
	echo "TODO"
	exit 1
;;
	*)
echo "unknown MODE: ${MODE}"
	exit 1
		;;
esac

# Prepare
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

A() { ${RUN} exec -T filebencha python benchmark.py -- filebench -f workloads/A/run.f;}
B() { ${RUN} exec -T filebenchb python benchmark.py -- filebench -f workloads/B/run.f;}

if [ $MODE == process ]
then
B() { ${RUN} exec -T filebencha python benchmark.py -- filebench -f workloads/B/run.f;}
fi

[ $MODE == Bonly ] || A | tee A.out &
[ $MODE == Aonly ] || B | tee B.out &

wait
wait

# Report
mkdir -p data/$MODE
for m in memory_stats blkio_stats networks cpu_stats filebench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$MODE/$m.csv
done
