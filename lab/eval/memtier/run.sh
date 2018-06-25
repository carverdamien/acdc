#!/bin/bash
set -x -e

[ -n "$CONFIG" ]

source kernel
[ -n "$KERNEL" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${MEMORY:=$((2**31))}

SIZE=$((2**12)) # 512MB max
REQUESTS=$((2*189841)) #
REQUESTS=$((REQUESTS/2))

EXTRA_INIT="-d ${SIZE} --key-pattern=S:S --key-maximum=${REQUESTS} --ratio=1:0 --requests=${REQUESTS} -c 1 -t 1"
EXTRA_HIGH="-d ${SIZE} --key-pattern=R:R --key-maximum=${REQUESTS} --ratio=0:1 -c 1 -t 1"
EXTRA_LOW="-d ${SIZE} --key-pattern=R:R --key-maximum=$((REQUESTS * 40 / 100)) --ratio=0:1 -c 1 -t 1"

IDLEMEMSTAT_CPU_LIMIT=1

once_prelude() { :; }
prelude() { :; }

case "$CONFIG" in
    "opt")
	MEMORY=$((3*2**31))
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
#${PRE} exec memtiera run -- memtier_benchmark -s redisa ${EXTRA_INIT}
#${PRE} exec redisa redis-cli save
#${PRE} exec memtierb run -- memtier_benchmark -s redisb ${EXTRA_INIT}
#${PRE} exec redisb redis-cli save
#${PRE} exec memtierc run -- memtier_benchmark -s redisc ${EXTRA_INIT}
#${PRE} exec redisc redis-cli save
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

A() { ${RUN} exec -T memtiera run -- memtier_benchmark -s redisa ${EXTRA_HIGH} --test-time 300; }
B() { ${RUN} exec -T memtierb run -- memtier_benchmark -s redisb ${EXTRA_HIGH} --test-time 300 &
    sleep 60;
    docker update --cpus 0.01 $(${RUN} ps -q redisb);
    sleep 180;
    docker update --cpus 1 $(${RUN} ps -q redisb);
}
C() { sleep 120;
    ${RUN} exec -T memtierc run -- memtier_benchmark -s redisc ${EXTRA_HIGH} --test-time 60
    #${PRE} exec memtierc run -- memtier_benchmark -s redisc ${EXTRA_INIT}
    #${PRE} exec redisc redis-cli save
}

${RUN} exec memtiera run -- memtier_benchmark -s redisa ${EXTRA_INIT}
${RUN} exec redisa redis-cli save

${RUN} exec memtierb run -- memtier_benchmark -s redisb ${EXTRA_INIT}
${RUN} exec redisb redis-cli save

B() { 
    ${RUN} exec -T memtierb run -- memtier_benchmark -s redisb ${EXTRA_HIGH} --test-time 60;
    sleep 180;
    ${RUN} exec -T memtierb run -- memtier_benchmark -s redisb ${EXTRA_HIGH} --test-time 60;
}

C() {
sleep 120
${RUN} exec memtierc run -- memtier_benchmark -s redisc ${EXTRA_INIT}
${RUN} exec -T redisc redis-cli save
sleep 60
${RUN} stop redisc
}

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
