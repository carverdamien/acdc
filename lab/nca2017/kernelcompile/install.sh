#!/bin/bash
set -x -e

KERNEL=4.6.0.nca+

cp -a ./boot/config-${KERNEL} /boot/config-${KERNEL}
cp -a ./boot/System.map-${KERNEL} /boot/System.map-${KERNEL}
cp -a ./boot/vmlinuz-${KERNEL} /boot/vmlinuz-${KERNEL}
cp -a ./modules/${KERNEL} /lib/modules/${KERNEL}
update-initramfs -c -k ${KERNEL}
update-grub
