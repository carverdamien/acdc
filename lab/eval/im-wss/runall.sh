export CONFIG
for CONFIG in $(cat configs)
do
    if [ -d data/$CONFIG ]
    then
	echo "rm -r data/$CONFIG"
    else
	bash run.sh
    fi
done
