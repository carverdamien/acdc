#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

df = pd.read_csv('sysbench_stats.csv')

plt.figure()
for label in ['redisa', 'redisb']:
	sel = df['hostname'] == label
	X = df['time'][sel]
	X = np.array(X, dtype='datetime64[ns]')
	Y = df['rtps'][sel]
	plt.plot(X,Y,label=label)
plt.legend()
plt.savefig(img)
