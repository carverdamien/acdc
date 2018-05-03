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
def set_defaults(args):
    if args.mysql_hostname == None:
        args.__dict__['mysql_hostname'] = 'mysql'
    if args.mysql_dbname == None:
        args.__dict__['mysql_dbname'] = 'dbname'
    return args
main_subparsers = main_parser.add_subparsers()

sysbench_bin_path = './sysbench/sysbench'
sysbench_lua_path = './sysbench/tests/db/oltp.lua'

def mysql_call(args):
    return ['mysql',
            '--host', args.mysql_hostname,
            '--port', args.mysql_port,
            '-u', user]

def sysbench_call(args):
    return [sysbench_bin_path,
            '--test=%s' % sysbench_lua_path,
            '--oltp-table-size=%d' % args.dbsize,
            '--mysql-db=%s' % args.mysql_dbname,
            '--mysql-host=%s' % args.mysql_hostname,
            '--mysql-port=%d' % args.mysql_port,
            '--mysql-user=%s' % user,
            '--mysql-password=%s' % password]

sysbench_expected_v05_intermediate_output = """[{}] timestamp: {timestamp}, threads: {threads}, tps: {trps}, reads: {rdps}, writes: {wrps}, response time: {rtps}ms ({}%), errors: {errps}, reconnects:  {recops}"""
sysbenchoutput_parser = parse.compile(sysbench_expected_v05_intermediate_output)

def wait_for_server_to_start(args):
    if args.wait > 0:
        time.sleep(args.wait)
        return
    while True:
        try:
            subprocess.check_call(mysql_call(args) + ['-e', 'show status'])
            break
        except Exception as e:
            print(e)
        print('Waiting for %s to start' % (args.mysql_hostname))
        time.sleep(1)
        
def prepare(args):
    args = set_defaults(args)
    wait_for_server_to_start(args)
    try:
        subprocess.check_call(mysql_call(args) + ['-e', 'CREATE DATABASE %s' % args.mysql_dbname])
        subprocess.check_call(sysbench_call(args) + ['prepare'])
    except Exception as e:
        print(e)
    finally:
        out = subprocess.check_output(mysql_call(args) + ['-D', args.mysql_dbname, '-e', 'select count(*) from sbtest1'])
        count = int(out.split('\n')[1])
        if count != args.dbsize:
            raise Exception('count != dbsize')
        #subprocess.check_call(mysql_call(args) + ['-e', 'shutdown'])

def run(args):
    client = influxdb.InfluxDBClient(host=args.influxdbhost,
                                    port=int(args.influxdbport),
                                    database=args.influxdbname)
    client.create_database(args.influxdbname)
    measurement = 'sysbench_stats'
    if args.mysql_hostname == None:
        args = set_defaults(args)
        wait_for_server_to_start(args)
        hostname = subprocess.check_output(mysql_call(args) + ['-BNe', 'select @@hostname;'])[:-1]
    else:
        wait_for_server_to_start(args)
        hostname = args.mysql_hostname
    tags = { 'hostname' : hostname }
    def callback(fields):
        client.write_points([p for p in influxformat(measurement, fields, tags=tags)])
    args.callback = callback
    call = sysbench_call(args) + ['--report-interval=1',
                            '--tx-rate=%d' % args.txrate,
                            '--max-requests=%d' % args.maxrequests,
                            '--max-time=%d' % args.duration,
                            '--num-threads=%d' % args.num_threads,
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
    main_parser.add_argument('--mysql-hostname', dest='mysql_hostname', type=str, nargs='?', default=None)
    main_parser.add_argument('--mysql-dbname', dest='mysql_dbname', type=str, nargs='?', default=None)
    main_parser.add_argument('--mysql-port', dest='mysql_port', type=int, nargs='?', default=3306)
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
    run_parser.add_argument('--num-threads', dest='num_threads', type=int, nargs='?', default=8)
    run_parser.set_defaults(func=run)
    run_parser.set_defaults(callback=dummy)

    args = main_parser.parse_args()
    args.func(args)

main()
