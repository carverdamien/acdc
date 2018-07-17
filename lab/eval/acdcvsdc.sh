#!/bin/bash
export CONFIG
for i in {0..9}
do
    for c in opt orcl nop dc acdc sacdc rr-0.01 ir-0.01 rr-0.1 ir-0.1 rr-0.9 ir-0.9
    do
	for d in acdcvsdc acdcvsdc2 acdcvsdc.1 acdcvsdc2.1
	do
	    CONFIG=$i-$c
	    docker ps -aq | xargs docker stop -t 0
	    (cd $d; [ -d "data/$CONFIG" ] || bash run.sh)
	done
    done
done