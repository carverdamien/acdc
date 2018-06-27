export CONFIG
for CONFIG in opt nop dc acdc rr-0 rr-$((32*4*2**10)) ir-0.01 ir-0.1
do
    if [ -d data/$CONFIG ]
    then
	echo "rm -r data/$CONFIG"
    else
	bash run.sh
    fi
done
