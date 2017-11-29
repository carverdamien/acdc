#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

kernels = ['10-vanilla', '12-nca', '14-iptb']
dfs = { kernel : pd.read_csv('%s/data/memory_stats.csv' % kernel) for kernel in kernels}

plt.figure()
for kernel in dfs:
	df = dfs[kernel]
	for label in ['redisa']:
		for metric in ['stats.pglost']:
			sel = df['com.docker.compose.service'] == label
			X = df['time'][sel]
			Y = df[metric][sel]
			X = np.array(X, dtype='datetime64[ns]')
			X = np.array(X - np.min(X), dtype='timedelta64[s]')
			sel = X < np.timedelta64(250, 's')
			sel = np.logical_and(sel, X > np.timedelta64(200, 's'))
			X = X[sel]
			Y = Y[sel]
			plt.plot(X,Y,label=kernel)
plt.legend()
plt.savefig(img)
