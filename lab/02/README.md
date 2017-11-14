Goal
====

Provide a mechanism to allow user to control the reclaim decisions during consolidation.

`memory.priority` is set to `0` by default. Cgroups with lower priority are trimmed first to protected the memory of cgroups with higher priority. (Highest priority is `0`).

See `./kernelcompile` for `Linux 4.6.0.02`
