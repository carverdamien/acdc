#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

labels = ['0.001', '0.01', '0.1', '1']

plt.figure()
for label in labels:
        try:
                df = pd.read_csv('%s/cpu_stats.csv' % (label))
                sel = df['com.docker.compose.service'] == 'scanner'
                X = df['time'][sel]
                X = np.array(X, dtype='datetime64[ns]')
                Y = df['percent_usage'][sel]
                X = X - X[0]
                plt.plot(X,Y,label=label)
        except Exception as e:
                print(e)
plt.legend()
plt.savefig(img)
