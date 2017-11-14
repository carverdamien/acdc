Goal
====

Provide a feedback metric to observe the reclaim decisions during consolidation.

`pglost` will account the total number of page lost by a cgroup because of another cgroup reaching the parent's limit.
`pgstolen` will account the total number of page that this cgroup reclaimed in other cgroups.
