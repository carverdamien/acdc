export CONFIG
for CONFIG in opt nop rr-0 rr-$((2**20)) ir-0.1 dc acdc
do
    if [ -d data/$CONFIG ]
    then
	echo 'rm -r data/$CONFIG'
    else
	bash run.sh
    fi
done
