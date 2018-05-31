#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

df = pd.read_csv('memory_stats.csv')

fig = plt.figure()
ax = fig.add_subplot(111)
for label in ['stats.recent_ratio_total', 'stats.recent_ratio_anon', 'stats.recent_ratio_file']:
	sel = df['com.docker.compose.service'] == 'filebench'
	X = df['time'][sel]
	X = np.array(X, dtype='datetime64[ns]')
	Y = df[label][sel]
	ax.plot(X,Y,label=label)
ax.legend()
ax.set_yscale('log')
plt.savefig(img)
