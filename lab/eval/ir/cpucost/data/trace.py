#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

labels = [
        1, 
        2, 
        4, 
        8, 
        10,
]

def process(df,N):
        df['time'] = df['time'] - df['time'][0]
        XMAX = max(df['time'])
        X = np.zeros(XMAX/N)
        Y = np.zeros(XMAX/N)
        xmin = 0
        xmax = N
        for i in range(len(X)):
                sel = np.logical_and(xmin <= df['time'], df['time'] < xmax)
                X[i] = xmin
                Y[i] = sum(df['delay'][sel])/N
                xmin += N
                xmax += N
        return X,Y

plt.figure()
for label in labels:
        try:
                df = pd.read_csv('%d/trace.csv' % (label))
                X,Y = process(df,label)
                plt.plot(X,Y,label=str(label))
        except Exception as e:
                print(e)
plt.yscale('log')
plt.legend()
plt.savefig(img)
