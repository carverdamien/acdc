export CONFIG
for CONFIG in rr-$((2**30)) opt nop rr-0 rr-$((2**20)) dc acdc ir-0.1
do
    if [ -d data/$CONFIG ]
    then
	echo 'rm -r data/$CONFIG'
    else
	bash run.sh
    fi
done
