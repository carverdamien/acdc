#!/bin/bash
set -x -e

PATH=$PATH:$PWD/grub-list
grub-reboot-on 4.6.0.nca+
