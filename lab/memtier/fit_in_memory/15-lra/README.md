# Goal

Show that nca should not be able to make the difference between

* A active (max rqs/s) and fits in memory (no pgin/s)
* B inactive (no rqs/s) (no pgin/s)

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

### mem
![mem](https://image.ibb.co/jhFP2w/mem.png "mem")
### pglost
![pglost](https://image.ibb.co/fq0DvG/pglost.png "pglost")
### pgstolen
![pgstolen](https://image.ibb.co/iTfP2w/pgstolen.png "pgstolen")
### ratio
![ratio](https://image.ibb.co/eMXtvG/ratio.png "ratio")
### rtps
![rtps](https://image.ibb.co/gJ3cNw/rtps.png "rtps")
### trps
![trps](https://image.ibb.co/jkQDvG/trps.png "trps")
