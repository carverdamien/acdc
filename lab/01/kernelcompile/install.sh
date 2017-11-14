#!/bin/bash
set -x -e

cp -a ./boot/* /boot
cp -a ./modules/* /lib/modules/
update-grub
