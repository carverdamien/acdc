#!/bin/bash
set -x -e

[ "$(uname -sr)" == "Linux 4.6.0.01+" ]

: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=3800358912}

# Prepare
docker-compose -f restricted.yml down
docker-compose -f unrestricted.yml down
docker-compose -f unrestricted.yml build
docker-compose -f unrestricted.yml create
docker-compose -f unrestricted.yml up -d
docker-compose -f unrestricted.yml exec sysbencha prepare --dbsize ${DBSIZE}
docker-compose -f unrestricted.yml exec sysbenchb prepare --dbsize ${DBSIZE}
docker-compose -f unrestricted.yml exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
docker-compose -f unrestricted.yml exec host bash -c '! [ -d /rootfs/sys/fs/cgroup/memory/consolidate ] || rmdir /rootfs/sys/fs/cgroup/memory/consolidate'
docker-compose -f unrestricted.yml exec host bash -c 'mkdir /rootfs/sys/fs/cgroup/memory/consolidate'
docker-compose -f unrestricted.yml exec host bash -c 'echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/memory.use_hierarchy'
docker-compose -f unrestricted.yml exec host bash -c 'echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/memory.oom_control'
docker-compose -f unrestricted.yml exec host bash -c "echo ${MEMORY} > /rootfs/sys/fs/cgroup/memory/consolidate/memory.limit_in_bytes"
docker-compose -f unrestricted.yml down

# Run
docker-compose -f restricted.yml create
docker-compose -f restricted.yml up -d
docker-compose -f restricted.yml exec sysbencha job run --dbsize ${DBSIZE} --duration 300
docker-compose -f restricted.yml exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 120
docker-compose -f restricted.yml exec cassandra job start
sleep 60
docker-compose -f restricted.yml exec cassandra job stop
sleep 60
docker-compose -f restricted.yml exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 60

# Report
docker-compose -f unrestricted.yml exec influxdb influx -database dockerstats   -execute 'select * from /.*/' -format=csv > dockerstats.csv
docker-compose -f unrestricted.yml exec influxdb influx -database sysbenchstats -execute 'select * from /.*/' -format=csv > sysbenchstats.csv
