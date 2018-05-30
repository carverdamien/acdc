#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

labels = [
        0.001,
        0.01,
        0.1,
        1,
]

def process(df,N):
        N = 1
        df['time'] = df['time'] - df['time'][0]
        XMAX = max(df['time'])
        Y = np.zeros(int(XMAX/N))
        X = np.zeros(int(XMAX/N))
        xmin = 0
        xmax = N
        for i in range(int(XMAX/N)):
                sel = np.logical_and(xmin <= df['time'], df['time'] < xmax)
                Y[i] = sum(df['delay'][sel])/N
                X[i] = xmin
                xmin += N
                xmax += N
        return X,Y

plt.figure()
for label in labels:
        try:
                df = pd.read_csv('%s/trace.csv' % str(label))
                X,Y = process(df,label)
                plt.plot(X,Y,label=label)
        except Exception as e:
                print(e)
plt.yscale('log')
plt.legend()
plt.savefig(img)
