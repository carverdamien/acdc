#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]



fig = plt.figure()
ax = fig.add_subplot(111)
for label in ['0.001', '0.01', '0.1', '1']:
        df = pd.read_csv('%s/memory_stats.csv' % label)
	sel = df['com.docker.compose.service'] == 'filebench'
	X = df['time'][sel]
	X = np.array(X, dtype='datetime64[ns]')
	Y = df['stats.recent_ratio_total'][sel]
        X = X - X[0]
	ax.plot(X,Y,label=label)
ax.legend()
ax.set_yscale('log')
plt.savefig(img)
