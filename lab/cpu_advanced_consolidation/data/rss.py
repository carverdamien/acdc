#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

df = pd.read_csv('memory_stats.csv')

plt.figure()
for label in ['mysqla', 'mysqlb', 'mysqlc']:
	sel = df['com.docker.compose.service'] == label
	X = df['time'][sel]
	X = np.array(X, dtype='datetime64[ns]')
	Y = df['stats.rss'][sel]
	Y /= 2**20
	plt.plot(X,Y,label=label)
plt.legend()
plt.savefig(img)
