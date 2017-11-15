#!/bin/bash
set -x -e

docker-compose -f compose/kernelcompile.yml build
docker-compose -f compose/kernelcompile.yml up
