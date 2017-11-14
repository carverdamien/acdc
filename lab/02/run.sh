#!/bin/bash
set -x -e

[ "$(uname -sr)" == "Linux 4.6.0.02+" ]

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
docker-compose -f unrestricted.yml exec host bash -c "echo ${MEMORY} > /rootfs/sys/fs/cgroup/memory/consolidate/memory.limit_in_bytes"
docker-compose -f unrestricted.yml down

# Run
docker-compose -f restricted.yml create
docker-compose -f restricted.yml up -d
# Get containers id
mysqla=$(docker-compose -f restricted.yml ps -q mysqla)
mysqlb=$(docker-compose -f restricted.yml ps -q mysqlb)
cassandra=$(docker-compose -f restricted.yml ps -q cassandra)
# set priority of mysqla to 1
docker-compose -f restricted.yml exec host bash -c "echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/${mysqla}/memory.priority"
# set priority of mysqlb to 1
docker-compose -f restricted.yml exec host bash -c "echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/${mysqlb}/memory.priority"
# set priority of cassandra to 2
docker-compose -f restricted.yml exec host bash -c "echo 2 > /rootfs/sys/fs/cgroup/memory/consolidate/${cassandra}/memory.priority"
docker-compose -f restricted.yml exec sysbencha job run --dbsize ${DBSIZE} --duration 300
docker-compose -f restricted.yml exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 60
# set priority of mysqla to 1 (NOP)
# set priority of mysqlb to 2
docker-compose -f restricted.yml exec host bash -c "echo 2 > /rootfs/sys/fs/cgroup/memory/consolidate/${mysqlb}/memory.priority"
# set priority of cassandra to 1
docker-compose -f restricted.yml exec host bash -c "echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/${cassandra}/memory.priority"
sleep 60
docker-compose -f restricted.yml exec cassandra job start
sleep 60
docker-compose -f restricted.yml exec cassandra job stop
# set priority of mysqla to 1 (NOP)
# set priority of mysqlb to 1
docker-compose -f restricted.yml exec host bash -c "echo 1 > /rootfs/sys/fs/cgroup/memory/consolidate/${mysqlb}/memory.priority"
# set priority of cassandra to 2
docker-compose -f restricted.yml exec host bash -c "echo 2 > /rootfs/sys/fs/cgroup/memory/consolidate/${cassandra}/memory.priority"
sleep 60
docker-compose -f restricted.yml exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 60

# Report
docker-compose -f unrestricted.yml exec influxdb influx -database dockerstats   -execute 'select * from /.*/' -format=csv > dockerstats.csv
docker-compose -f unrestricted.yml exec influxdb influx -database sysbenchstats -execute 'select * from /.*/' -format=csv > sysbenchstats.csv
