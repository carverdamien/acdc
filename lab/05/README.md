# Goal

1. Use `nr_rotated` and `nr_scanned` to update `memory.priority`.
2. Provide a mechanism to update the metrics.

When user writes `4k*x` in `memory.force_scan`, the cgroup will be scanned and at least `x` pages will move in its LRUs. (But the cgroup will not lose the pages)

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.
