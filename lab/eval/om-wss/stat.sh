HA=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(trps) from sysbench_stats where hostname='highmysqla'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
HB=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(trps) from sysbench_stats where hostname='highmysqlb'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
HC=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(trps) from sysbench_stats where hostname='highmysqlc'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
H=$(python <<<  "print($HA+$HB+$HC)")
LA=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(trps) from sysbench_stats where hostname='lowmysqla'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
LB=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(trps) from sysbench_stats where hostname='lowmysqlb'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
LC=$(docker exec acdcvsdc_influxdb_1 influx -database acdc -execute "select cumulative_sum(trps) from sysbench_stats where hostname='lowmysqlc'" | sed '/^$/d' | tail -n 1 | cut -d ' ' -f2)
L=$(python <<<  "print($LA+$LB+$LC)")
echo $H $L | tee -a stat.out
