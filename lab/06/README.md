# Goal

Use `nr_rotated` and `nr_scanned` to update `memory.priority`.
Use `memory.force_scan` to update the `nr_rotated` and `nr_scanned`.

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.
