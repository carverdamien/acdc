#!/bin/bash
export CONFIG
for i in {0..99}
do
    for c in opt opt-ir-0.9 opt-rr-0.9 orcl nop dc acdc sacdc rr-0.01 ir-0.01 rr-0.1 ir-0.1 rr-0.9 ir-0.9
    do
	for d in {om,im}-{wss,rate}
	do
	    CONFIG=$i-$c
	    (
		cd $d
		source kernel
		if [ -n "$KERNEL" ]
		then
		    if [ "$(uname -sr)" == "Linux ${KERNEL}" ]
		    then
			if ! [ -d "data/$CONFIG" ]
			then
			    sudo killall initctl
			    docker ps -aq | xargs docker stop -t 0
			    bash run.sh
			fi
		    else
			bash scripts/reboot.sh
		    fi
		fi
	    )
	done
    done
done
