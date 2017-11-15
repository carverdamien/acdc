#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]

PATH="${PATH}:${PWD}/utils/grub-list"
grub-reboot-on "${KERNEL}"
