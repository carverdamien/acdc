# Goal

Use `nr_rotated` and `nr_scanned` to update `memory.priority`.
Use `memory.force_scan` to update the `nr_rotated` and `nr_scanned`.

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

### mem
![mem](https://image.ibb.co/hV6XOR/mem.png "mem")
### priority
![priority](https://image.ibb.co/bKy1Hm/priority.png "priority")
### ratio
![ratio](https://image.ibb.co/cbwXOR/ratio.png "ratio")
### rtps
![rtps](https://image.ibb.co/c8agHm/rtps.png "rtps")
### trps
![trps](https://image.ibb.co/eCoOV6/trps.png "trps")
