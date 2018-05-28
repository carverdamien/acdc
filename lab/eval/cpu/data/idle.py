#!/usr/bin/env python
import pandas as pd
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import sys

img = sys.argv[1]

plt.figure()
for label in ['1','2', '4', '8', '10']:
        try:
                df = pd.read_csv('%s/idlemem_stats.csv' % (label))
                metric = 'idle_total_ratio'
                sel = df['com.docker.compose.service'] == 'filebench'
                X = df['time'][sel]
                X = np.array(X, dtype='datetime64[ns]')
                Y = df[metric][sel]
                X = X - X[0]
                plt.plot(X,Y,label=label)
        except Exception as e:
                print(e)
plt.legend()
plt.savefig(img)
