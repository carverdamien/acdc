# DISCLAIMER

The disk io bandwith of redisa is set very low `128kb`.
The intended effect is to observe performance drop as soon as memory has to be reload from disk.

check `grep -B7 -A3 -r blkio_config .`

### pglost
![bar](https://image.ibb.co/b95yvG/bar.png "bar")
![bar](https://image.ibb.co/ke7p2w/pglost.png "pglost")
