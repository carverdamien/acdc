#!/bin/bash
set -x -e

KERNEL=4.6.0.02+

rm -rf /lib/modules/${KERNEL}
rm -f /boot/config-${KERNEL} /boot/System.map-${KERNEL} /boot/vmlinuz-${KERNEL} /boot/initrd.img-${KERNEL}
update-grub
