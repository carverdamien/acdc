export CONFIG
for CONFIG in rr-$((32*4*2**10)) rr-$((2**21)) rr-$((2**20)) rr-0 opt nop dc acdc ir-0.1 ir-0.01 ir-0.2 ir-0.8 ir-1.0
do
    if [ -d data/$CONFIG ]
    then
	echo 'rm -r data/$CONFIG'
    else
	bash run.sh
    fi
done
