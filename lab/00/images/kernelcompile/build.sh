#!/bin/bash
set -x -e

docker-compose build
docker-compose up
