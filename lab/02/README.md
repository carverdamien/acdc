# Goal

Provide a mechanism to allow user to control the reclaim decisions during consolidation.

`memory.priority` is set to `0` by default. Cgroups with lower priority are trimmed first to protected the memory of cgroups with higher priority. (Highest priority is `0`).

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.
