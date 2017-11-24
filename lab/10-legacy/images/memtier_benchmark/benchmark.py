import subprocess
import time
import argparse
import parse
import influxdb
import datetime

"""[RUN #1 100%,  10 secs]  0 threads:      768875 ops,   75412 (avg:   76884) ops/sec, 2.80MB/sec (avg: 2.85MB/sec),  0.66 (avg:  0.65) msec latency"""

def run(args):
    client = influxdb.InfluxDBClient(host=args.influxdbhost,
                                    port=int(args.influxdbport),
                                    database=args.influxdbname)
    client.create_database(args.influxdbname)
    measurement = 'memtier_stats'
    tags = {}
    def callback(fields):
        client.write_points([p for p in influxformat(measurement, fields, tags=tags)])

    call = args.call
    print(call)
    p = subprocess.Popen(call, stdout=subprocess.PIPE)
    for line in p.stdout:
        print(line)

def influxformat(measurement, fields, tags={}):
    t = datetime.datetime.utcfromtimestamp(int(fields['timestamp']))
    del fields['timestamp']
    point = {
        "measurement": measurement,
        "tags": tags,
        "time": t,
        "fields": { k:float(fields[k]) for k in fields},
    }
    yield point

def main():
    main_parser = argparse.ArgumentParser()
    main_subparsers = main_parser.add_subparsers()

    run_parser = main_subparsers.add_parser('run')
    run_parser.add_argument("--influxdbname", dest="influxdbname", type=str, nargs=1, default='acdc')
    run_parser.add_argument("--influxdbhost", dest="influxdbhost", type=str, nargs=1, default='influxdb')
    run_parser.add_argument("--influxdbport", dest="influxdbport", type=str, nargs=1, default='8086')
    run_parser.add_argument('call', metavar='N', type=str, nargs='+')

    args = main_parser.parse_args()
    run(args)

main()
