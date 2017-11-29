# Goal

Provide a mechanism to allow user to control the reclaim decisions during consolidation.

`memory.priority` is set to `0` by default. Cgroups with lower priority are trimmed first to protected the memory of cgroups with higher priority. (Highest priority is `0`).

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

### mem
![mem](https://image.ibb.co/kiPmiR/mem.png "mem")
### pglost
![pglost](https://image.ibb.co/gbie3R/pglost.png "pglost")
### pgstolen
![pgstolen](https://image.ibb.co/e5jK3R/pgstolen.png "pgstolen")
### priority
![priority](https://image.ibb.co/gX7vcm/priority.png "priority")
### ratio
![ratio](https://image.ibb.co/iDCiV6/ratio.png "ratio")
### rtps
![rtps](https://image.ibb.co/f14xq6/rtps.png "rtps")
### trps
![trps](https://image.ibb.co/h5Je3R/trps.png "trps")
