# Goal

Test if the memory of active containers is protected during consolidation.

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

## Obervation

If `recent_scanned/recent_rotated` was updated in mysqlb, we could use it to detect its inactivity.
