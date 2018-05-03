#!/bin/bash
export MODE
for MODE in isolated noshares not_isolated process standalone
do
	bash run.sh
done
