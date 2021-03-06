# Goal

Provide a feedback metric to observe the reclaim decisions during consolidation.

`pglost` will account the total number of page lost by a cgroup because of another cgroup reaching the parent's limit.
`pgstolen` will account the total number of page that this cgroup reclaimed in other cgroups.

We need `pglost` and `pgstolen` when the diskIO bandwidth is high enough to hide the bad decisions by quickly recovering swapped pages.
In this case, the system is paying in IO for its mistakes, but what if IO gets scarce, or write lifetime of disk gets shorter.

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

### mem
![mem](https://image.ibb.co/b4EDV6/mem.png "mem")
### pglost
![pglost](https://image.ibb.co/j2sdxm/pglost.png "pglost")
### pgstolen
![pgstolen](https://image.ibb.co/cjNdxm/pgstolen.png "pgstolen")
### ratio
![ratio](https://image.ibb.co/de9fA6/ratio.png "ratio")
### rtps
![rtps](https://image.ibb.co/kjNYV6/rtps.png "rtps")
### trps
![trps](https://image.ibb.co/gXFnq6/trps.png "trps")
