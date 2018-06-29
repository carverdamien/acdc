#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${SCALE:=1}
: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=$((2*2**30))}

SCANNER_CPU_LIMIT=1
IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }

case "$CONFIG" in
    "opt")
	MEMORY=$((3*2**30))
	;;
    "nop")
	;;
    rr-*.*)
	SCANNER_CPU_LIMIT=${CONFIG##rr-}
	once_prelude() { ${RUN} exec scanner job reclaimordersetter /rootfs/sys/fs/cgroup/memory/parent $((2**20)) 0; }
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
sed "s/\${IDLEMEMSTAT_CPU_LIMIT}/${IDLEMEMSTAT_CPU_LIMIT}/" compose/restricted.yml |
sed "s/\${SCANNER_CPU_LIMIT}/${SCANNER_CPU_LIMIT}/" > compose/.restricted.yml

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

CYCLE=60
NCYCLE=6
TOTSEC=$((NCYCLE * CYCLE))

A() { ${RUN} exec -T sysbencha python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate 0 --duration ${TOTSEC}; }
B() { ${RUN} exec -T sysbenchb python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate 0 --duration ${TOTSEC}; }
C() { ${RUN} exec -T sysbenchc python benchmark.py --wait=0 run --dbsize ${DBSIZE} --tx-rate 0 --duration ${TOTSEC}; }

mysqla() { ${RUN} ps -q mysqla; }
mysqlb() { ${RUN} ps -q mysqlb; }
mysqlc() { ${RUN} ps -q mysqlc; }

move_tasks() { for task in $(cat $1/tasks); do echo $task | sudo tee $2/tasks; done; }

for mysql in mysqlb mysqlc
do
    move_tasks "/sys/fs/cgroup/blkio/parent/$($mysql)" "/sys/fs/cgroup/blkio/parent/$(mysqla)"
done

docker update --cpus 0.01 $(mysqlb)
docker update --cpus 0.01 $(mysqlc)
oldmysql=mysqlc

A | tee a.out &
B | tee b.out &
C | tee c.out &

sleep $CYCLE
docker update --cpus 8 $(mysqlb)
sleep $CYCLE

for mysql in mysqla mysqlb mysqlc mysqla
do
    docker update --cpus 0.01 $($mysql)
    docker update --cpus   8 $($oldmysql)
    oldmysql=$mysql
    sleep $CYCLE
done

wait
wait
wait

# Report
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "$DATA_DIR/$m.csv"
done
