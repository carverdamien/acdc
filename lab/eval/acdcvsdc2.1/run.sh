#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${MEM:=$((2**30))}
: ${MEMORY:=$((2*MEM))}

: ${HIGH_DBSIZE:=10000000}
:  ${LOW_DBSIZE:=100000}

SCANNER_CPU_LIMIT=1
IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }

activate()   { :; }
deactivate() { :; }

case "$CONFIG" in
    *-opt)
	MEMORY=$((3*2**30))
	;;
    *-nop)
	;;
	*orcl)
	activate()   { echo -1 | sudo tee "/sys/fs/cgroup/memory/parent/$1/memory.soft_limit_in_bytes"; }
	deactivate() { echo  0 | sudo tee "/sys/fs/cgroup/memory/parent/$1/memory.soft_limit_in_bytes"; }
	;;
    *-rr-*.*)
	SCANNER_CPU_LIMIT=${CONFIG##*rr-}
	SCAN=$((2**20))
	if [ "$SCANNER_CPU_LIMIT" == "0.01" ]
	then
	    SCAN=0
	fi
	once_prelude() { ${RUN} exec scanner job reclaimordersetter /rootfs/sys/fs/cgroup/memory/parent ${SCAN} 0; }
	;;
    *-ir-*.*)
	IDLEMEMSTAT_CPU_LIMIT=${CONFIG##*ir-}
	# once_prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateSoftLimit; }
	once_prelude() { ${RUN} exec idlememstat job idlememstat -d 0 --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateReclaimOrder; }
	;;
    *-ir-*)
	IDLEMEMSTAT_DELAY=${CONFIG##*ir-}
	# once_prelude() { ${RUN} exec idlememstat job idlememstat -d ${IDLEMEMSTAT_DELAY} --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateSoftLimit; }
	once_prelude() { ${RUN} exec idlememstat job idlememstat -d ${IDLEMEMSTAT_DELAY} --influxdbhost influxdb --influxdbname=acdc --cgroup /rootfs/sys/fs/cgroup/memory/parent --updateReclaimOrder; }
	;;
    *-acdc)
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_clock_{demand,activate}"; }
	;;
    *-sacdc)
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_{clock_demand,clock_activate,scan}"; }
	;;
    *-dc)
	prelude() { ${RUN} exec host bash -c "echo 1 | tee /rootfs/sys/fs/cgroup/memory/parent/$1/memory.use_clock_demand"; }
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

${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec sysbencha prepare --dbsize ${HIGH_DBSIZE}
${PRE} exec sysbenchb prepare --dbsize ${HIGH_DBSIZE}
${PRE} exec sysbenchc prepare --dbsize ${HIGH_DBSIZE}
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

CYCLE=30

slow()   { docker exec --privileged $1 tc qdisc add dev eth0 root netem loss 10%; }
unslow() { docker exec --privileged $1 tc qdisc del dev eth0 root; }

X() { activate $(mysql$1); ${RUN} exec -T sysbench$1 python benchmark.py --wait=0 --mysql-dbname dbname --mysql-hostname highmysql$1 run --dbsize ${HIGH_DBSIZE} --tx-rate 0 --duration ${CYCLE}; deactivate $(mysql$1); }
_() { slow  $(sysbench$1); ${RUN} exec -T sysbench$1 python benchmark.py --wait=0 --mysql-dbname dbname --mysql-hostname lowmysql$1  run --dbsize ${HIGH_DBSIZE} --tx-rate 0 --duration ${CYCLE}; unslow $(sysbench$1); }

A() { X a; X a; _ a; X a; X a; _ a; X a; X a; _ a; X a; X a; _ a; }
B() { _ b; X b; X b; _ b; X b; X b; _ b; X b; X b; _ b; X b; X b; }
C() { X c; _ c; X c; X c; _ c; X c; X c; _ c; X c; X c; _ c; X c; }

mysqla() { ${RUN} ps -q mysqla; }
mysqlb() { ${RUN} ps -q mysqlb; }
mysqlc() { ${RUN} ps -q mysqlc; }
sysbencha() { ${RUN} ps -q sysbencha; }
sysbenchb() { ${RUN} ps -q sysbenchb; }
sysbenchc() { ${RUN} ps -q sysbenchc; }

move_tasks() { for task in $(cat $1/tasks); do echo $task | sudo tee $2/tasks; done; }
# move_tasks() { :; }

for mysql in mysqlb mysqlc
do
    move_tasks "/sys/fs/cgroup/blkio/parent/$($mysql)" "/sys/fs/cgroup/blkio/parent/$(mysqla)"
done

deactivate $(mysqla)
deactivate $(mysqlb)
deactivate $(mysqlc)

A | tee a.out &
B | tee b.out &
C | tee c.out &

wait

# Report
for m in $(${PRE} exec influxdb influx -database acdc -execute 'show measurements' -format=csv |  sed 's/\r//g' | tail -n+2 | cut -d, -f2)
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "$DATA_DIR/$m.csv"
done

# Export Report
RSYNC() {
NAME=$(readlink -e "$1")
DIRNAME=$(dirname ${NAME})
ssh lab2 "mkdir -p ~/lab1/${DIRNAME}"
rsync -azvP "${NAME}" "lab2:~/lab1/${DIRNAME}"
}
RSYNC "${DATA_DIR}" || true
