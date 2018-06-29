#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${SCALE:=2}
: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=3800358912}

IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }

case "$CONFIG" in
    "opt")
	MEMORY=$((2**31+2516901888))
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
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c 'echo cfq > /sys/block/sda/queue/scheduler'
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/memory/parent ] || rmdir /rootfs/sys/fs/cgroup/memory/parent'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/memory/parent'
${PRE} exec host bash -c 'echo 1 > /rootfs/sys/fs/cgroup/memory/parent/memory.use_hierarchy'
${PRE} exec host bash -c "echo ${MEMORY} > /rootfs/sys/fs/cgroup/memory/parent/memory.limit_in_bytes"
${PRE} exec host bash -c "echo 0 > /rootfs/proc/sys/kernel/randomize_va_space"
${PRE} down

# Run
${RUN} create
${RUN} up -d

for c in mysqla mysqlb cassandra
do
    prelude $(${RUN} ps -q $c)
done

once_prelude $(for c in mysqla mysqlb cassandra; do ${RUN} ps -q $c; done)

MAXTXR=390                # Max on one core
MAXTXR=520
MAXTXR=585
MAXTXR=600
MAXTXR=2000
MEDTXR=$((MAXTXR*50/100)) # Medium is 50%
LOWTXR=$((MAXTXR*10/100)) # Low is 10%
WAMTXR=$LOWTXR
LOWTXR=1
BRTTXR=$((MAXTXR*2))      # Extra requests on a second (burst)

WARM=60

TIMEA0=$WARM
TIMEA1=$((100 * SCALE)) # Time A is medium
TIMEA2=$((100 * SCALE)) # Time A is medium
TIMEA3=$((100 * SCALE)) # Time A is medium

TIMEB0=$WARM
TIMEB1=$((060 * SCALE)) # Time B is medium
TIMEB2=$((180 * SCALE)) # Time B is low
TIMEB3=$((060 * SCALE)) # Time B is medium

NA0=$((TIMEA0 * WAMTXR))
NA1=$((TIMEA1 * MEDTXR + NA0))
NA2=$((TIMEA2 * MEDTXR + NA1))
NA3=$((TIMEA3 * MEDTXR + NA2))

NB0=$((TIMEB0 * WAMTXR))
NB1=$((TIMEB1 * MEDTXR + NB0))
NB2=$((TIMEB2 * LOWTXR + NB1))
NB3=$((TIMEB3 * MEDTXR + NB2))

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate ${WAMTXR} --scheduled-rate=${WAMTXR},${MEDTXR},${MEDTXR},${MEDTXR} --scheduled-time=0,0,0,0 --scheduled-requests=${NA0},${NA1},${NA2},${NA3} --max-requests ${NA3};}
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate ${WAMTXR} --scheduled-rate=${WAMTXR},${MEDTXR},${LOWTXR},${MEDTXR} --scheduled-time=0,0,0,0 --scheduled-requests=${NB0},${NB1},${NB2},${NB3} --max-requests ${NB3};}
C() { sleep $WARM; sleep $((120 * SCALE)); ${RUN} exec -T cassandra job start; sleep $((60*SCALE)); ${RUN} exec -T cassandra job stop; }

A | tee a.out &
B | tee b.out &
C | tee c.out &

wait
wait
wait

# Report
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "$DATA_DIR/$m.csv"
done