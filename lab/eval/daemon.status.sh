#!/bin/bash
status () 
{ 
tr '\0' '\n' < "/proc/$(pgrep docker-compose | head -n 1 | cut -d ' ' -f 1)/environ" | grep --color=auto -E 'CONFIG|PWD';
}
status
