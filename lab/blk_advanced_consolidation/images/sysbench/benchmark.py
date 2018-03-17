import subprocess
import time
import argparse
import parse
import influxdb
import datetime

main_parser = argparse.ArgumentParser()
# TODO
user = 'root'
password = ''
host = 'mysql'
dbname = 'dbname'
main_subparsers = main_parser.add_subparsers()

sysbench_bin_path = './sysbench/sysbench'
sysbench_lua_path = './sysbench/tests/db/oltp.lua'

mysql_call = ['mysql',
              '--host', host,
              '-u', user]

def sysbench_call(dbsize):
    return [sysbench_bin_path,
            '--test=%s' % sysbench_lua_path,
            '--oltp-table-size=%d' % dbsize,
            '--mysql-db=%s' % dbname,
            '--mysql-host=%s' % host,
            '--mysql-user=%s' % user,
            '--mysql-password=%s' % password]

sysbench_expected_v05_intermediate_output = """[{}] timestamp: {timestamp}, threads: {threads}, tps: {trps}, reads: {rdps}, writes: {wrps}, response time: {rtps}ms ({}%), errors: {errps}, reconnects:  {recops}"""
sysbenchoutput_parser = parse.compile(sysbench_expected_v05_intermediate_output)

def wait_for_server_to_start():
    while True:
        try:
            subprocess.check_call(mysql_call + ['-e', 'show status'])
            break
        except Exception as e:
            print(e)
        print('Waiting for %s to start' % (host))
        time.sleep(1)
        
def prepare(args):
    try:
        subprocess.check_call(mysql_call + ['-e', 'CREATE DATABASE %s' % dbname])
        subprocess.check_call(sysbench_call(args.dbsize) + ['prepare'])
    except Exception as e:
        print(e)
    finally:
        out = subprocess.check_output(mysql_call + ['-D', dbname, '-e', 'select count(*) from sbtest1'])
        count = int(out.split('\n')[1])
        if count != args.dbsize:
            raise Exception('count != dbsize')
        #subprocess.check_call(mysql_call + ['-e', 'shutdown'])

def run(args):
    client = influxdb.InfluxDBClient(host=args.influxdbhost,
                                    port=int(args.influxdbport),
                                    database=args.influxdbname)
    client.create_database(args.influxdbname)
    measurement = 'sysbench_stats'
    tags = {
        'hostname' : subprocess.check_output(mysql_call + ['-BNe', 'select @@hostname;'])[:-1]
    }
    def callback(fields):
        client.write_points([p for p in influxformat(measurement, fields, tags=tags)])
    args.callback = callback

    call = sysbench_call(args.dbsize) + ['--report-interval=1',
                            '--tx-rate=%d' % args.txrate,
                            '--max-requests=%d' % args.maxrequests,
                            '--max-time=%d' % args.duration,
                            '--num-threads=%d' % 8,
                            '--oltp-read-only=on',
                            '--scheduled-rate=%s' % ','.join(args.scheduled_rate),
                            '--scheduled-time=%s' % ','.join(args.scheduled_time),
                            '--scheduled-requests=%s' % ','.join(args.scheduled_requests),
                            'run']
    p = subprocess.Popen(call, stdout=subprocess.PIPE)
    for line in p.stdout:
        res = sysbenchoutput_parser.search(line)
        if res == None:
            print(line)
        else:
            args.callback(dict(res.named))

def dummy(*args,**kwargs):
    pass

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
    main_parser.add_argument('--wait', dest="wait", type=int, nargs='?', default=-1)
    prepare_parser = main_subparsers.add_parser('prepare')
    prepare_parser.add_argument('--dbsize',   dest="dbsize", type=int, nargs='?', default=10000)
    prepare_parser.set_defaults(func=prepare)
    run_parser = main_subparsers.add_parser('run')
    run_parser.add_argument("--influxdbname", dest="influxdbname", type=str, nargs=1, default='acdc')
    run_parser.add_argument("--influxdbhost", dest="influxdbhost", type=str, nargs=1, default='influxdb')
    run_parser.add_argument("--influxdbport", dest="influxdbport", type=str, nargs=1, default='8086')
    run_parser.add_argument('--dbsize',   dest="dbsize", type=int, nargs='?', default=10000)
    run_parser.add_argument('--duration', dest="duration", type=int, nargs='?', default=0)
    run_parser.add_argument('--tx-rate', dest="txrate", type=int, nargs='?', default=0)
    run_parser.add_argument('--max-requests', dest="maxrequests", type=int, nargs='?', default=0)
    run_parser.add_argument('--scheduled-rate', dest="scheduled_rate", type=str, nargs=1, default='')
    run_parser.add_argument('--scheduled-time', dest="scheduled_time", type=str, nargs=1, default='')
    run_parser.add_argument('--scheduled-requests', dest="scheduled_requests", type=str, nargs=1, default='')
    run_parser.set_defaults(func=run)
    run_parser.set_defaults(callback=dummy)

    args = main_parser.parse_args()
    
    if args.wait > 0:
        time.sleep(args.wait)
    elif args.wait < 0:
        wait_for_server_to_start()
    args.func(args)

main()
