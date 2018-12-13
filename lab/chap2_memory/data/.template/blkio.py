#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
mpl.colors.ColorConverter.colors['colora'] = (51./255, 102./255, 204./255)
mpl.colors.ColorConverter.colors['colorb'] = (255./255, 153./255, 0./255)
mpl.colors.ColorConverter.colors['active'] = (.5,.5,.5)
mpl.colors.ColorConverter.colors['inactive'] = (.7,.7,.7)
import matplotlib.pyplot as plt
import numpy as np
import sys
import os

font = { 'size' : 20,}
mpl.rc('font', **font)
OneSec = np.timedelta64(1, 's')

img = sys.argv[1]

basename = os.path.basename(sys.argv[0])
basename = os.path.splitext(basename)[0]
config,_ = basename.split('-')

df = pd.read_csv('%s/blkio_stats.csv' % config)

figsize = (6.4*1.6, 4.8)
fig = plt.figure(figsize=figsize)
ax = fig.add_subplot(111)

for service in ['filebencha','filebenchb']:
	sel = df['com.docker.compose.service'] == service
	X = np.array(df['time'][sel], dtype='datetime64[ns]')
	X = (X - X[0])/OneSec
	Y = df['Rbps'][sel]
	Y = Y/(2**20)
	ax.plot(X,Y,label=service)

# ax.legend()
fig.savefig(img)
