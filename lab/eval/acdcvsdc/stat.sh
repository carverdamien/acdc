HA=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='highredisa'" | tail -n 1 | cut -d ' ' -f2)
HB=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='highredisb'" | tail -n 1 | cut -d ' ' -f2)
HC=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='highredisc'" | tail -n 1 | cut -d ' ' -f2)
H=$((HA+HB+HC))
LA=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='lowredisa'" | tail -n 1 | cut -d ' ' -f2)
LB=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='lowredisb'" | tail -n 1 | cut -d ' ' -f2)
LC=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(opsps) from memtier_stats where hostname='lowredisc'" | tail -n 1 | cut -d ' ' -f2)
L=$((LA+LB+LC))
echo $H $L | tee -a stat.out
