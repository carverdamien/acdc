#!/bin/bash
export MODE
for MODE in fmlock baseline 2mcgl 2mcgm
do
    bash run.sh
done
# make -j 4 -C data
