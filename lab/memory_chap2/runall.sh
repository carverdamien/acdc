#!/bin/bash
export MODE
for MODE in process isolated Aonly Bonly
do
	bash run.sh
done
