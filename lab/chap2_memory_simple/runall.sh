#!/bin/bash
export MODE
for MODE in baseline automatic manual
do
    bash run.sh
done
make -j 4 -C data
