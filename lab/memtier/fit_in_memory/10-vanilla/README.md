# Goal

Show that nca should not be able to make the difference between

* A active (max rqs/s) and fits in memory (no pgin/s)
* B inactive (no rqs/s) (no pgin/s)

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.
