export CONFIG
for CONFIG in opt nop dc acdc ir-0.01 ir-0.1 rr-0.01 rr-0.1 rr-0.02 rr-0.03 rr-0.04 rr-0.05 rr-0.06 rr-0.07 rr-0.08
do
    if [ -d data/$CONFIG ]
    then
	echo "rm -r data/$CONFIG"
    else
	bash run.sh
    fi
done
