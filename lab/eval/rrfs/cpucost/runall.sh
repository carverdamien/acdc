export SCAN
MB=$((2**20))
for SCAN in $MB $((4*MB)) $((8*MB)) $((16*MB)) $((32*MB)) $((64*MB)) $((128*MB))
do
    bash run.sh
done
