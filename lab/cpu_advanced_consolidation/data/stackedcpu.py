#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

df = pd.read_csv('cpu_stats.csv')

labels = ['mysqla', 'mysqlb', 'mysqlc']

def f():
	for label in labels:
		sel = df['com.docker.compose.service'] == label
		X = df['time'][sel]
		X = np.array(X, dtype='datetime64[ns]')
		X = 10**-9*np.array(X - X[0], dtype='double')
		Y = df['percent_usage'][sel]
		yield X, Y, label

plt.figure()

x,y,l = next(f())
y = np.row_stack((y for x,y,l in f()))
plt.stackplot(x,y,labels=labels)

plt.legend(title='With Isolation')
plt.savefig(img)
