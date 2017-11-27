#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]
[ "$(uname -sr)" == "Linux ${KERNEL}" ]

: ${MEMORY:=4874100736}

SIZE=$((2**12)) # 512MB max
REQUESTS=$((2*189841)) #$((2**30/${SIZE}/2))
EXTRAINIT="-p 11211 -P memcache_text -d ${SIZE} --key-pattern=S:S --key-maximum=${REQUESTS} --ratio=1:0 --requests=${REQUESTS} -c 1 -t 1"

RUN="docker-compose --project-directory $PWD -f compose/restricted.yml"
PRE="docker-compose --project-directory $PWD -f compose/unrestricted.yml"

# Prepare
${RUN} down
${PRE} down
${PRE} build
${PRE} create
${PRE} up -d
#${PRE} exec memtiera run -- memtier_benchmark -s redisa ${EXTRAINIT} #debug
#${PRE} exec memtierb run -- memtier_benchmark -s redisb ${EXTRAINIT} #debug
${PRE} exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
${PRE} exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/memory/consolidate ] || rmdir /rootfs/sys/fs/cgroup/memory/consolidate'
${PRE} exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/memory/consolidate'
${PRE} exec host bash -c 'echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/memory.use_hierarchy'
${PRE} exec host bash -c "echo ${MEMORY} > /rootfs/sys/fs/cgroup/memory/consolidate/memory.limit_in_bytes"
#exit #debug
${PRE} down

EXTRA="-p 11211 -P memcache_text -d ${SIZE} --key-pattern=R:R --key-maximum=${REQUESTS} --ratio=1:10 -c 1 -t 1"

# Run
${RUN} create
${RUN} up -d
#${RUN} exec redisa redis-cli config set maxmemory 2gb
#${RUN} exec redisa redis-cli config set maxmemory-policy allkeys-lru
#${RUN} exec redisa redis-cli config set appendonly no
#${RUN} exec redisb redis-cli config set maxmemory 2gb
#${RUN} exec redisb redis-cli config set maxmemory-policy allkeys-lru
#${RUN} exec redisb redis-cli config set appendonly no
${RUN} exec memtiera run -- memtier_benchmark -s redisa ${EXTRAINIT}
${RUN} exec memtierb run -- memtier_benchmark -s redisb ${EXTRAINIT}
${RUN} exec memtiera job run -- memtier_benchmark -s redisa ${EXTRA} --test-time 300
${RUN} exec memtierb job run -- memtier_benchmark -s redisb ${EXTRA} --test-time 60
sleep 120
${RUN} exec cassandra job start
sleep 60
${RUN} exec cassandra job stop
sleep 60
${RUN} exec memtierb job run -- memtier_benchmark -s redisb ${EXTRA} --test-time 60
sleep 60

# Report
for m in memory_stats blkio_stats networks cpu_stats memtier_stats
do
	${PRE} exec influxdb influx -database acdc -execute "select * from $m" -format=csv > data/$m.csv
done
