#!/bin/bash
set -x -e

source kernel
[ -n ${KERNEL} ]

PATH=$PATH:$PWD/images/kernelcompile/grub-list
grub-reboot-on ${KERNEL}
