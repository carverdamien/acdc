#!/bin/bash
set -x -e

source kernel
[ -n "${KERNEL}" ]

cp -a "./build/kernel/boot/config-${KERNEL}" "/boot/config-${KERNEL}"
cp -a "./build/kernel/boot/System.map-${KERNEL}" "/boot/System.map-${KERNEL}"
cp -a "./build/kernel/boot/vmlinuz-${KERNEL}" "/boot/vmlinuz-${KERNEL}"
cp -a "./build/kernel/modules/${KERNEL}" "/lib/modules/${KERNEL}"
update-initramfs -c -k "${KERNEL}"
update-grub
