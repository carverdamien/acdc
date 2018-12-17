#!/bin/bash
export MODE
for MODE in baseline 2mcgl 2mcgm
do
    bash run.sh
done
# make -j 4 -C data
