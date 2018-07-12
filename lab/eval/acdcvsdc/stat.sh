HA=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='highredisa'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
HB=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='highredisb'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
HC=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='highredisc'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
H=$(python <<<  "print($HA+$HB+$HC)")
LA=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='lowredisa'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
LB=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='lowredisb'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
LC=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='lowredisc'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
L=$(python <<<  "print($LA+$LB+$LC)")
echo $H $L | tee -a stat.out
