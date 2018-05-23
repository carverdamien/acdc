#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

kernels = [
'00-c-legacy-with-pg-lost-stolen',
'01-manual-mechanism-with-priority',
'02-nca',
'03-b-force_scan-update_ratio_scan_rotate-mechanism',
'04-b-idle_page_tracking_bitaccesed-mechanism',
'05-lra',
]
dfs = { kernel : pd.read_csv('%s/data/memory_stats.csv' % kernel) for kernel in kernels}

# Rename
_kernels = ['vanilla', 'A<C<B', 'pgd', 'rr', 'ir', 'pgda']
dfs = {_kernels[i] : dfs[kernels[i]] for i in range(len(kernels))}
kernels = _kernels

plt.figure()

def yielder():
	i = 0
	for kernel in kernels:
		df = dfs[kernel]
		for label in ['mysqla']:
			for metric in ['stats.pglost']:
				i = i+1
				sel = df['com.docker.compose.service'] == label
				X = df['time'][sel]
				Y = df[metric][sel]
				X = np.array(X, dtype='datetime64[ns]')
				X = np.array(X - np.min(X), dtype='timedelta64[s]')
				sel = X < np.timedelta64(250, 's')
				sel = np.logical_and(sel, X > np.timedelta64(200, 's'))
				X = X[sel]
				Y = Y[sel]
				yield i, np.max(Y), '.'.join([kernel])
X = []
Y = []
T = []
for x, y, t in yielder():
	X.append(x)
	Y.append(y)
	T.append(t)
plt.bar(X,Y)
plt.yscale('log')
# plt.yticks([10**3,10**4,10**5])
plt.xticks(X, T)
plt.savefig(img)
