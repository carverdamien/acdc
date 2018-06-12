#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

MEMORY=$((2**31)) # 2GB

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"

prelude() { :; }

case "$CONFIG" in
    "opt")
	MEMORY=$((3*2**30)) # 3GB
	;;
    "rr-*")
	SCAN=${CONFIG##rr-}
	prelude() { ${RUN} exec scanner job scan /rootfs/sys/fs/cgroup/memory/docker/$1 ${SCAN} 1; }
	;;
    "ir-*")
	IDLEMEMSTAT_CPU_LIMIT=${CONFIG##ir-}
	RUN="docker-compose --project-directory $PWD -f compose/.restricted.yml"
	sed "s/\${IDLEMEMSTAT_CPU_LIMIT}/${IDLEMEMSTAT_CPU_LIMIT}/" compose/restricted.yml > compose/.restricted.yml
	prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/docker --updateSoftLimit; }
	;;
    "dc")
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_clock_demand"; }
	;;
    "acdc")
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_clock_{demand,activate}"; }
	;;
    *)
	echo "Unknown CONFIG: $CONFIG"
	exit 1;;
esac

# Prepare
DATA_DIR="data/$CONFIG/"
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

for c in filebencha filebenchb filebenchc
do
    prelude $(${RUN} ps -q $c)
done

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
