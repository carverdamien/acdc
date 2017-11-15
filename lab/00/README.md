Goal
====

Test if the memory of active containers is protected during consolidation.

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./boot` and `./modules`.
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.
