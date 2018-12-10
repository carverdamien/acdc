#!/bin/bash
export MODE
for MODE in baseline 1mcg 2mcgm 2mcgl
do
    bash run.sh
done
