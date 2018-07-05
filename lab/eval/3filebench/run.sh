#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${NCYCLE:=6}
: ${CYCLE:=60}
: ${MEM:=$((2**30))}
: ${MEMORY:=$((2*MEM))}

SCANNER_CPU_LIMIT=1
IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }

activated() { :; }
deactivated() { :; }

case "$CONFIG" in
    *opt)
	MEMORY=$((3*2**30))
	;;
    *nop)
	;;
	*orcl)
	activated()   { echo -1 | sudo tee "/sys/fs/cgroup/memory/parent/$1/memory.soft_limit_in_bytes"; }
	deactivated() { echo  0 | sudo tee "/sys/fs/cgroup/memory/parent/$1/memory.soft_limit_in_bytes"; }
	;;
    *rr-*.*)
	SCANNER_CPU_LIMIT=${CONFIG##*rr-}
	once_prelude() { ${RUN} exec scanner job reclaimordersetter /rootfs/sys/fs/cgroup/memory/parent $((2**20)) 0; }
	;;
    *ir-*.*)
	IDLEMEMSTAT_CPU_LIMIT=${CONFIG##*ir-}
	# once_prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateSoftLimit; }
	once_prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateReclaimOrder; }
	;;
    *ir-*)
	IDLEMEMSTAT_DELAY=${CONFIG##*ir-}
	# once_prelude() { ${RUN} exec idlememstat job idlememstat -d ${IDLEMEMSTAT_DELAY} --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateSoftLimit; }
	once_prelude() { ${RUN} exec idlememstat job idlememstat -d ${IDLEMEMSTAT_DELAY} --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateReclaimOrder; }
	;;
    *dc)
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_clock_demand"; }
	;;
    *acdc)
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_clock_{demand,activate}"; }
	;;
    *)
	echo "Unknown CONFIG: $CONFIG"
	exit 1;;
esac

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/.restricted.yml"
sed "s/\${IDLEMEMSTAT_CPU_LIMIT}/${IDLEMEMSTAT_CPU_LIMIT}/" compose/restricted.yml |
sed "s/\${MEM}/${MEM}/" |
sed "s/\${SCANNER_CPU_LIMIT}/${SCANNER_CPU_LIMIT}/" > compose/.restricted.yml

# Prepare
DATA_DIR="data/$CONFIG/"
mkdir -p "$DATA_DIR"
make -B -C workloads CYCLE=${CYCLE} MEM=${MEM} NCYCLE=${NCYCLE}
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec filebencha filebench -f workloads/filebencha/prepare.f
${PRE} exec filebenchb filebench -f workloads/filebenchb/prepare.f
${PRE} exec filebenchc filebench -f workloads/filebenchc/prepare.f
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

once_prelude $(for c in filebencha filebenchb filebenchc; do ${RUN} ps -q $c; done)

X() { ${RUN} exec -T $1 python benchmark.py -- filebench -f workloads/$1/waste.f; }
ABG() { X filebencha; }
BBG() { X filebenchb; }
CBG() { X filebenchc; }

Y() { activated $($1); ${RUN} exec -T $1 python benchmark.py -- filebench -f workloads/$1/reuse.f; deactivated $($1) }
A() { Y filebencha; }
B() { Y filebenchb; }
C() { Y filebenchc; }

filebencha() { ${RUN} ps -q filebencha; }
filebenchb() { ${RUN} ps -q filebenchb; }
filebenchc() { ${RUN} ps -q filebenchc; }

move_tasks() { for task in $(cat $1/tasks); do echo $task | sudo tee $2/tasks; done; }
move_tasks() { :; }

for filebench in filebenchb filebenchc
do
    move_tasks "/sys/fs/cgroup/blkio/parent/$($filebench)" "/sys/fs/cgroup/blkio/parent/$(filebencha)"
done

deactivated $(filebencha)
deactivated $(filebenchb)
deactivated $(filebenchc)

ABG | tee a.out &
BBG | tee b.out &
CBG | tee c.out &

sched1() { A; C; B; }
sched2() { sleep $CYCLE; B; A; C; }

sched1 | tee sched1.out &
sched2 | tee sched2.out &

wait
wait
wait
wait
wait

# Report
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "$DATA_DIR/$m.csv"
done
