#!/bin/bash
set -x -e
: ${DBSIZE:=10000000}


compose() { docker-compose -f unrestricted.yml $@; }

compose down
compose up -d --build
compose exec sysbencha prepare --dbsize ${DBSIZE}
compose exec sysbenchb prepare --dbsize ${DBSIZE}
compose exec host bash -c 'echo 3 > /rootfs/proc/sys/vm/drop_caches'
compose down

compose() { docker-compose -f restricted.yml $@; }
compose up -d