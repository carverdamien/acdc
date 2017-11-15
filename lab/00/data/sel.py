#! /usr/bin/env python

# Examples:
# python sel.py trps hostname=mysqlb < sysbenchstats.csv
# python sel.py usage name=memory_stats com.docker.compose.service=mysqla < dockerstats.csv

# TODO: put yname at the end. Examples:
# python sel.py hostname=mysqlb trps < sysbenchstats.csv
# python sel.py com.docker.compose.service=mysqla name=memory_stats usage < dockerstats.csv

import sys
import pandas as pd
import numpy as np
import itertools
import csv

yname = sys.argv[1]

df = pd.read_csv(sys.stdin)

X = df['time']
Y = df[yname]

sel = np.ones(Y.shape, dtype=bool)

label = []
if len(sys.argv) > 1:
	for arg in sys.argv[2:]:
		var,val = arg.split('=')
		sel = np.logical_and(sel, df[var] == val)
		label.append(val)
label.append(yname)
label = '.'.join(label)

writer =  csv.writer(sys.stdout)
for x,y,z in itertools.izip(X[sel],Y[sel],itertools.repeat(label)):
	writer.writerow([x,y,z])
