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

export TIME_SCALE=2

case $MODE in
baseline)
MEMORY=$((MEMORY*2))
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebencha -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebenchb -f workloads/B/run.f;}
;;
#1mcg)
#RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebencha -f workloads/A/run.f;}
#RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebenchb -f workloads/B/run.f;}
#;;
2mcgm)
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebencha -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebenchb -f workloads/B/run.f;}
;;
2mcgl)
N=$((2**4))
N=$((2**5))
# N=$((2**6)) # B fails
N=2
MEMA=$((MEMORY*(N-1)/N))
MEMB=$((MEMORY*1/N))
RUNA() { ${RUN} exec -T filebencha job python benchmark.py -- filebencha -f workloads/A/run.f;}
RUNB() { ${RUN} exec -T filebenchb job python benchmark.py -- filebenchb -f workloads/B/run.f;}
;;
*)
echo "unknown MODE: ${MODE}"
exit 1
;;
esac

sed "s/\${MEMA}/${MEMA}/"   compose/restricted.yml |
sed "s/\${MEMB}/${MEMB}/" > compose/.restricted.yml

# Prepare
make -B -C workloads/A
make -B -C workloads/B
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
${PRE} exec fincore cp -a linux-fadvise /shared/
${PRE} down

# Run
${RUN} create
${RUN} up -d

# Copy filebench
${RUN} exec -T filebencha cp -a /usr/local/bin/filebench{,a}
${RUN} exec -T filebenchb cp -a /usr/local/bin/filebench{,b}

filebencha() { ${RUN} ps -q filebencha; }
filebenchb() { ${RUN} ps -q filebenchb; }
move_tasks() { for task in $(cat $1/tasks); do echo $task | sudo tee $2/tasks; done; }
waitend() { for f in filebencha filebenchb; do while ${RUN} ps -q $f | xargs docker top | grep -q filebench; do sleep 1; done; done; }

case $MODE in
    1mcg)
	move_tasks "/sys/fs/cgroup/memory/parent/$(filebenchb)" "/sys/fs/cgroup/memory/parent/$(filebencha)"
	;;
    *)
	;;
esac

# Start ftrace
# DATA_DIR="data/$MODE"
# mkdir -p ${DATA_DIR}
# TRACE_DAT=/${DATA_DIR}/trace.dat
# ${RUN} exec host rm -f ${TRACE_DAT}*
# ${RUN} exec -T host job trace-cmd record -p function_graph -l try_to_free_mem_cgroup_pages -g try_to_free_mem_cgroup_pages -o ${TRACE_DAT}

RUNA | tee A.out &
RUNB | tee B.out &

waitend

# Stop ftrace
# ${RUN} exec host bash -c 'kill -s SIGINT $(pgrep trace-cmd)'
# while ${RUN} exec host pgrep trace-cmd; do echo 'waiting'; sleep 1; done

# Report
DATA_DIR="data/$MODE"
mkdir -p "${DATA_DIR}"
for m in memory_stats blkio_stats networks cpu_stats filebench_stats fincore_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > "${DATA_DIR}/$m.csv"
done
