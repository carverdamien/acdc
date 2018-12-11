#!/bin/bash
exec python wrapper.py -- linux-fincore $(find $1 -type f)
