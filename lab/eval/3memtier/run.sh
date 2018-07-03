#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${SCALE:=16}
: ${MEM:=$((2**30/SCALE))}
: ${MEMORY:=$((2*MEM+10*2**20))}

SIZE=$((2**12)) # 512MB max
REQUESTS=$((189841/SCALE))
REQUESTS=$((REQUESTS-1280))

THREADS=2
EXTRA_INIT="-d ${SIZE} --key-pattern=S:S --key-maximum=${REQUESTS} --ratio=1:0 --requests=${REQUESTS} -c 1 -t ${THREADS}"
EXTRA_HIGH="-d ${SIZE} --key-pattern=R:R --key-maximum=${REQUESTS} --ratio=0:1 -c 1 -t ${THREADS}"
EXTRA_LOW="-d ${SIZE} --key-pattern=R:R --key-maximum=$((REQUESTS * 40 / 100)) --ratio=0:1 -c 1 -t ${THREADS}"

SCANNER_CPU_LIMIT=1
IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }
activate() { docker update --cpus 8 $1; }
deactivate() { docker update --cpus 0.01 $1; }

case "$CONFIG" in
    *opt)
	MEMORY=$((3*2**30))
	;;
    *nop)
	;;
	*orcl)
	activate()   { echo -1 | sudo tee "/sys/fs/cgroup/memory/parent/$1/memory.soft_limit_in_bytes"; docker update --cpus 8 $1; }
	deactivate() { echo 0 | sudo tee "/sys/fs/cgroup/memory/parent/$1/memory.soft_limit_in_bytes"; docker update --cpus 0.01 $1; }
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

${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec memtiera run -- memtier_benchmark -s redisa ${EXTRA_INIT}
${PRE} exec redisa redis-cli save
${PRE} exec memtierb run -- memtier_benchmark -s redisb ${EXTRA_INIT}
${PRE} exec redisb redis-cli save
${PRE} exec memtierc run -- memtier_benchmark -s redisc ${EXTRA_INIT}
${PRE} exec redisc redis-cli save
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

for c in redisa redisb redisc
do
    prelude $(${RUN} ps -q $c)
done

once_prelude $(for c in redisa redisb redisc; do ${RUN} ps -q $c; done)

CYCLE=60
NCYCLE=6
TOTSEC=$((NCYCLE * CYCLE))

A() { ${RUN} exec -T memtiera run -- memtier_benchmark -s redisa ${EXTRA_HIGH} --test-time ${TOTSEC}; }
B() { ${RUN} exec -T memtierb run -- memtier_benchmark -s redisb ${EXTRA_HIGH} --test-time ${TOTSEC}; }
C() { ${RUN} exec -T memtierc run -- memtier_benchmark -s redisc ${EXTRA_HIGH} --test-time ${TOTSEC}; }

redisa() { ${RUN} ps -q redisa; }
redisb() { ${RUN} ps -q redisb; }
redisc() { ${RUN} ps -q redisc; }

move_tasks() { for task in $(cat $1/tasks); do echo $task | sudo tee $2/tasks; done; }

for redis in redisb redisc
do
    move_tasks "/sys/fs/cgroup/blkio/parent/$($redis)" "/sys/fs/cgroup/blkio/parent/$(redisa)"
done

deactivate $(redisb)
deactivate $(redisc)
oldredis=redisc

A | tee a.out &
B | tee b.out &
C | tee c.out &

sleep $CYCLE
activate $(redisb)
sleep $CYCLE

for redis in redisa redisb redisc redisa
do
    deactivate $($redis)
    activate   $($oldredis)
    oldredis=$redis
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
