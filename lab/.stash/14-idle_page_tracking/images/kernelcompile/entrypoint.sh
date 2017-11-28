#!/bin/bash
set -e -x

: ${CORE:=$(grep -c processor /proc/cpuinfo)}
make -C linux ${EXTRA} -j ${CORE}
make -C linux modules_install install
