#!/bin/bash
set -x -e
: ${DBSIZE:=10000000} # Use small value for debug
: ${MEMORY:=3800358912}
: ${CGROUP:=/sys/fs/cgroup/memory/consolidate}

compose() { docker-compose -f unrestricted.yml $@; }

# Prepare
compose down
compose up -d --build
compose exec sysbencha prepare --dbsize ${DBSIZE}
compose exec sysbenchb prepare --dbsize ${DBSIZE}
compose exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
compose exec host bash -c 'rm -rf           /rootfs/${CGROUP}'
compose exec host bash -c 'mkdir            /rootfs/${CGROUP}'
compose exec host bash -c 'echo 1 >         /rootfs/${CGROUP}/memory.use_hierarchy'
compose exec host bash -c 'echo ${MEMORY} > /rootfs/${CGROUP}/memory.limit_in_bytes'
compose down

compose() { docker-compose -f restricted.yml $@; }

# Run
compose up -d
compose exec sysbencha job run --dbsize ${DBSIZE} --duration 300
compose exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 120
compose exec cassandra job start
sleep 60
compose exec cassandra job stop
sleep 60
compose exec sysbenchb job run --dbsize ${DBSIZE} --duration 60
sleep 60

# Report
docker-compose -f unrestricted.yml exec influxdb influx -database dockerstats   -execute 'select * from /.*/' -format=csv > dockerstats.csv
docker-compose -f unrestricted.yml exec influxdb influx -database sysbenchstats -execute 'select * from /.*/' -format=csv > sysbenchstats.csv
