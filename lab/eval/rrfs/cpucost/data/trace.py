#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

labels = ['0.001', '0.01', '0.1', '1']

def process(df):
        df['time'] = df['time'] - df['time'][0]
        X = np.arange(max(df['time']))
        Y = np.zeros(len(X))
        for i in range(len(X)-1):
                xmin = X[i]
                xmax = X[i+1]
                sel = np.logical_and(xmin <= df['time'], df['time'] < xmax)
                Y[i] = sum(df['delay'][sel])
        return X,Y

plt.figure()
for label in labels:
        try:
                df = pd.read_csv('%s/trace.csv' % (label))
                X,Y = process(df)
                plt.plot(X,Y,label=label)
        except Exception as e:
                print(e)
plt.legend()
plt.savefig(img)
