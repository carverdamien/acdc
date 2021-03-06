#!/bin/bash
export CONFIG
until docker info; do echo 'Waiting for docker daemon to start'; sleep 1; done
for i in {0..99}
do
    for c in opt orcl unf nop dc acdc sacdc ir-0.1 ir-1.0 opt-ir-0.1 opt-ir-1.0 rr-0.01 rrs-0.1 rrs-1.0 opt-rrs-0.1 opt-rrs-1.0
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
