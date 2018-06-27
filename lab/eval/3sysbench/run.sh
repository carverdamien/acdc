#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${SCALE:=1}
: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=$((2*2**30))}

IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }

case "$CONFIG" in
    "opt")
	MEMORY=$((3*2**30))
	;;
    "nop")
	;;
    rr-*)
	SCAN=${CONFIG##rr-}
	prelude() { ${RUN} exec scanner job scan /rootfs/sys/fs/cgroup/memory/parent/$1 ${SCAN} 1; }
	# once_prelude() { ${RUN} exec scanner job softlimitsetter /rootfs/sys/fs/cgroup/memory/parent 1 $@; }
	once_prelude() { ${RUN} exec scanner job reclaimordersetter /rootfs/sys/fs/cgroup/memory/parent 1; }
	;;
    ir-*.*)
	IDLEMEMSTAT_CPU_LIMIT=${CONFIG##ir-}
	# once_prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateSoftLimit; }
	once_prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateReclaimOrder; }
	;;
    ir-*)
	IDLEMEMSTAT_DELAY=${CONFIG##ir-}
	# once_prelude() { ${RUN} exec idlememstat job idlememstat -d ${IDLEMEMSTAT_DELAY} --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateSoftLimit; }
	once_prelude() { ${RUN} exec idlememstat job idlememstat -d ${IDLEMEMSTAT_DELAY} --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateReclaimOrder; }
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

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/.restricted.yml"
sed "s/\${IDLEMEMSTAT_CPU_LIMIT}/${IDLEMEMSTAT_CPU_LIMIT}/" compose/restricted.yml > compose/.restricted.yml

# Prepare
DATA_DIR="data/$CONFIG/"
mkdir -p "$DATA_DIR"

${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec sysbencha prepare --dbsize ${DBSIZE}
${PRE} exec sysbenchb prepare --dbsize ${DBSIZE}
${PRE} exec sysbenchc prepare --dbsize ${DBSIZE}
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

for c in mysqla mysqlb mysqlc
do
    prelude $(${RUN} ps -q $c)
done

once_prelude $(for c in mysqla mysqlb mysqlc; do ${RUN} ps -q $c; done)

MAXTXR=1000
TOTSEC=300
SWITCH=2

REQA=$((MAXTXR*TOTSEC))
REQBC=$((REQA/2/SWITCH))

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate 0 --max-requests ${REQA}; }
BC() {
	for switch in $(seq $SWITCH)
	do
		for sysbench in sysbenchb sysbenchc
		do
			${RUN} exec -T ${sysbench} python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate 0 --max-requests ${REQBC}
		done
	done
}

A  | tee a.out &
BC | tee b.out &

wait
wait

# Report
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "$DATA_DIR/$m.csv"
done
