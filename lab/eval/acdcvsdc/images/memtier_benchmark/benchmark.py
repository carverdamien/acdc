import subprocess
import time
import argparse
import parse
import influxdb
import datetime
import os
import math

expected_output = """[{}] {timestamp} timestamp: {threads} threads: {ops} ops, {opsps} (avg: {avgopsps}) ops/sec, {bw}/sec (avg: {avgbw}/sec), {lat} (avg: {avglat}) msec latency"""
output_parser = parse.compile(expected_output)

def run(args):
    client = influxdb.InfluxDBClient(host=args.influxdbhost,
                                    port=int(args.influxdbport),
                                    database=args.influxdbname)
    client.create_database(args.influxdbname)
    measurement = 'memtier_stats'
    tags = {
        'hostname' : args.hostname[0],
    }
    def callback(fields):
        client.write_points([p for p in influxformat(measurement, fields, tags=tags)])

    call = args.call
    print(call)
    p = subprocess.Popen(call, stdout=subprocess.PIPE)
    for line in p.stdout:
        res = output_parser.search(line)
        if res == None:
            print(line)
        else:
            try:
                callback(res.named)
            except Exception as e:
                print(line)
                print(res.named)
                print(e)

def influxformat(measurement, fields, tags={}):
    t = datetime.datetime.utcfromtimestamp(int(fields['timestamp']))
    del fields['timestamp']
    point = {
        "measurement": measurement,
        "tags": tags,
        "time": t,
        "fields": { k:float(fields[k]) for k in fields if not math.isnan(float(fields[k])) },
    }
    yield point

def main():
    main_parser = argparse.ArgumentParser()
    main_subparsers = main_parser.add_subparsers()

    run_parser = main_subparsers.add_parser('run')
    run_parser.add_argument("--influxdbname", dest="influxdbname", type=str, nargs=1, default='acdc')
    run_parser.add_argument("--influxdbhost", dest="influxdbhost", type=str, nargs=1, default='influxdb')
    run_parser.add_argument("--influxdbport", dest="influxdbport", type=str, nargs=1, default='8086')
    run_parser.add_argument("--hostname", dest="hostname", type=str, nargs=1, default=os.environ['HOSTNAME'])
    run_parser.add_argument('call', metavar='N', type=str, nargs='+')

    args = main_parser.parse_args()
    run(args)

main()
