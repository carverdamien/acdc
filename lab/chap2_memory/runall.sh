#!/bin/bash
export MODE
for MODE in baseline 2mcgl 1mcg 2mcgm
do
    bash run.sh
done
