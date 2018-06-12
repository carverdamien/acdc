#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

memory = 2**31
metic = 'usage'

kernels = ['4.6.0+', '4.6.0.eval+', '4.6.0.june+']
labels = ['filebencha', 'filebenchb', 'filebenchc']

nfig = len(kernels) + len(labels)
fig, ax = plt.subplots(nfig,1,figsize=(6.4*2, 4.8*nfig))

def f(kernel,ax):
    ax.set_title('Kernel %s' % (kernel))
    df = pd.read_csv('data/%s/%d/memory_stats.csv' % (kernel,memory))
    xmin = min(df['time'])
    for label in labels:
        sel = df['com.docker.compose.service'] == label
        X = np.array(df['time'][sel], dtype='datetime64[ns]')
        X = np.array(np.array(X - xmin, dtype='timedelta64[ns]'), dtype='float')
        Y = np.array(df[metic][sel], dtype='float')
        ax.plot(X,Y,label=label)
        ax.legend()
        xticks = ax.get_xticks()
        ax.set_xticklabels([str(int(10**-9*x)) for x in xticks])
        yticks = ax.get_yticks()
        ax.set_yticklabels([str(int(y/2**20)) for y in yticks])

def g(label,ax):
    ax.set_title('Filebench %s' % (label))
    for kernel in kernels:
        df = pd.read_csv('data/%s/%d/memory_stats.csv' % (kernel,memory))
        xmin = min(df['time'])
        sel = df['com.docker.compose.service'] == label
        X = np.array(df['time'][sel], dtype='datetime64[ns]')
        X = np.array(np.array(X - xmin, dtype='timedelta64[ns]'), dtype='float')
        Y = np.array(df[metic][sel], dtype='float')
        ax.plot(X,Y,label=kernel)
        ax.legend()
        xticks = ax.get_xticks()
        ax.set_xticklabels([str(int(10**-9*x)) for x in xticks])
        yticks = ax.get_yticks()
        ax.set_yticklabels([str(int(y/2**20)) for y in yticks])

i=0
for kernel in kernels:
    f(kernel,ax[i])
    i+=1
for label in labels:
    g(label,ax[i])
    i+=1

plt.savefig(img)
