export CONFIG
for CONFIG in rr-$((2**30)) rr-$((2**21)) rr-$((2**20)) rr-0 opt nop dc acdc ir-0.1
do
    if [ -d data/$CONFIG ]
    then
	echo 'rm -r data/$CONFIG'
    else
	bash run.sh
    fi
done
