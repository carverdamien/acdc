#!/bin/bash
export MODE
# for MODE in Aonly Bonly isolated noshares not_isolated process standalone
# for MODE in Aonly Bonly not_isolated isolated
for MODE in process isolated Aonly Bonly
do
	bash run.sh
done
