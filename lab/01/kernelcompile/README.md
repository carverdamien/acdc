* `patch.txt` is based on `v4.6`. (consider only this file for your custom build)
* `build.sh` builds the kernel in a docker container and put the files in `./boot` and `./modules`.
* `install.sh` installs the kernel on the host.
* `reboot.sh` reboots the machine on this kernel.

For `./grub-list`
```
git submodule init
git submodule update
```
