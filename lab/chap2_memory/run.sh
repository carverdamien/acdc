#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"
RUN="docker-compose --project-directory $PWD -f compose/.restricted.yml"

MEMORY=$((2**30))
MEMA=$MEMORY
MEMB=$MEMORY

case $MODE in
baseline)
MEMORY=$((MEMORY*2))
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebench -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebench -f workloads/B/run.f;}
;;
1mcg)
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebench -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebench -f workloads/B/run.f;}
;;
2mcgm)
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebench -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebench -f workloads/B/run.f;}
;;
2mcgl)
MEMA=$((MEMORY*7/8))
MEMB=$((MEMORY*1/8))
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebench -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebench -f workloads/B/run.f;}
;;
*)
echo "unknown MODE: ${MODE}"
exit 1
;;
esac

sed "s/\${MEMA}/${MEMA}/"   compose/restricted.yml |
sed "s/\${MEMB}/${MEMB}/" > compose/.restricted.yml

# Prepare
make -C workloads/A
make -C workloads/B
${RUN} down --remove-orphans
${PRE} down --remove-orphans
${PRE} build
${PRE} create
${PRE} up -d
${PRE} exec filebencha filebench -f workloads/A/prepare.f
${PRE} exec filebenchb filebench -f workloads/B/prepare.f
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

filebencha() { ${RUN} ps -q filebencha; }
filebenchb() { ${RUN} ps -q filebenchb; }
move_tasks() { for task in $(cat $1/tasks); do echo $task | sudo tee $2/tasks; done; }
waitend() { for f in filebencha filebenchb; do while ${RUN} ps -q $f | xargs docker top | grep filebench; do sleep 1; done; done; }

case $MODE in
    1mcg)
	move_tasks "/sys/fs/cgroup/memory/parent/$(filebenchb)" "/sys/fs/cgroup/memory/parent/$(filebencha)"
	;;
    *)
	;;
esac

RUNA | tee A.out &
RUNB | tee B.out &

waitend

# Report
mkdir -p "data/$MODE"
for m in memory_stats blkio_stats networks cpu_stats filebench_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "data/$MODE/$m.csv"
done
