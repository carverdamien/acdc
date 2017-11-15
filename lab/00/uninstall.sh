#!/bin/bash
set -x -e

source kernel
[ -n ${KERNEL} ]

rm /boot/config-${KERNEL} /boot/System.map-${KERNEL} /boot/vmlinuz-${KERNEL} /boot/initrd.img-${KERNEL}
rm -r /lib/modules/${KERNEL}

update-grub
