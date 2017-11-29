# Goal

Provide a mechanism to update `nr_rotated` and `nr_scanned`.

When user writes `4k*x` in `memory.force_scan`, the cgroup will be scanned and at least `x` pages will move in its LRUs. (But the cgroup will not lose the pages)

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

### mem
![mem](https://image.ibb.co/iwL93R/mem.png "mem")
### ratio
![ratio](https://image.ibb.co/dS3kcm/ratio.png "ratio")
### rtps
![rtps](https://image.ibb.co/kXC0A6/rtps.png "rtps")
### trps
![trps](https://image.ibb.co/eOb5cm/trps.png "trps")
