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
func = 'try_to_free_mem_cgroup_pages'

def aggregate(df,sel,N):
        XMAX = max(df['time'][sel])
        Y = np.zeros(int(XMAX/N))
        X = np.zeros(int(XMAX/N))
        xmin = 0
        xmax = N
        for i in range(int(XMAX/N)):
                mysel = np.logical_and(xmin <= df['time'], df['time'] < xmax)
                mysel = np.logical_and(sel, mysel)
                Y[i] = sum(df['delay'][mysel])/N
                X[i] = xmin
                xmin += N
                xmax += N
        return X,Y

# X0 = np.datetime64(min(pd.read_csv('%s/fincore_stats.csv' % config)['time']), 'ns')
df = pd.read_csv('%s/trace.csv' % config)
# trace-cmd outputs in seconds
df['time'] = df['time'] - min(df['time']) # X0 = 0

figsize = (6.4*1.6, 4.8)
fig = plt.figure(figsize=figsize)
ax = fig.add_subplot(111)

# for proc in np.unique(df['proc']):
#         sel = df['proc'] == proc
#         sel = np.logical_and(sel, df['func'] == func)
#         X, Y = aggregate(df,sel,1)
#         Y = np.cumsum(Y)
#         ax.plot(X,Y,label=proc)
X = df['time']
Y = np.cumsum(df['delay'])
ax.plot(X,Y)
ax.set_yscale('log')
# ax.legend()
fig.savefig(img)



