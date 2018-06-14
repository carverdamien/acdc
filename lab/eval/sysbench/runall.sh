export CONFIG
for CONFIG in ir-2 opt nop rr-0 rr-$((2**20)) dc acdc
do
    if [ -d data/$CONFIG ]
    then
	echo 'rm -r data/$CONFIG'
    else
	bash run.sh
    fi
done
