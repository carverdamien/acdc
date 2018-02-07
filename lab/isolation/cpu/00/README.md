# Goal

Test if the memory of active containers is protected during consolidation.

## scripts

* `run.sh` runs the experiment.
* `build.sh` builds the kernel in a docker container and put the files in `./build/kernel/`
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

## Obervation

If `recent_scanned/recent_rotated` was updated in mysqlb, we could use it to detect its inactivity.

### Mem
![mem](https://image.ibb.co/jwWktR/mem.png "mem")
### Ratio
![ratio](https://image.ibb.co/g3qOf6/ratio.png "ratio")
### rtps
![rtps](https://image.ibb.co/mfrktR/rtps.png "rtps")
### trps
![trps](https://image.ibb.co/e09G06/trps.png "trps")
