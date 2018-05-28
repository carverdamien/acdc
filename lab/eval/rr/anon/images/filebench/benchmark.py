import subprocess
import time
import argparse
import influxdb
import datetime
import json

def grep_json(line):
    assert(type(line) == str)
    o = c = 0
    for n in range(len(line)):
        if line[n] == '{':
            if o == 0:
                i = n
            o += 1
        elif line[n] == '}':
            c += 1
            j = n
    if o == c and o > 0:
        line = line[i:j+1]
        print(line)
        try:
            return json.loads(line)
        except Exception as e:
            print(e)
    return None

def run(args):
    client = influxdb.InfluxDBClient(host=args.influxdbhost,
                                    port=int(args.influxdbport),
                                    database=args.influxdbname)
    client.create_database(args.influxdbname)
    print(args.call)
    p = subprocess.Popen(args.call, stdout=subprocess.PIPE)
    for line in p.stdout:
        line = line[:-1]
        res = grep_json(line)
        if res == None:
            print(line)
        else:
            print(res)
            client.write_points([res])

def main():
    main_parser = argparse.ArgumentParser()
    main_parser.add_argument("--influxdbname", dest="influxdbname", type=str, nargs=1, default='acdc')
    main_parser.add_argument("--influxdbhost", dest="influxdbhost", type=str, nargs=1, default='influxdb')
    main_parser.add_argument("--influxdbport", dest="influxdbport", type=str, nargs=1, default='8086')
    main_parser.add_argument('call', metavar='call', type=str, nargs='+')
    args = main_parser.parse_args()
    run(args)

main()
