#!/bin/bash
export MODE
for MODE in Aonly Bonly isolated noshares not_isolated process standalone
do
	bash run.sh
done
