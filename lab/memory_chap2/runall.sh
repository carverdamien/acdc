#!/bin/bash
export MODE
# Baseline: Aonly + Bonly
# Single memcgrp: process
# Two memcgrps A+B<Root: isolatedless
# Two memcgrps A+B>Root: isolatedmore
for MODE in process isolatedless isolatedmore Aonly Bonly
do
	bash run.sh
done
