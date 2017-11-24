#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]

docker-compose -p "${KERNEL}" --project-directory "${PWD}" -f compose/kernelcompile.yml build
docker-compose -p "${KERNEL}" --project-directory "${PWD}" -f compose/kernelcompile.yml up
