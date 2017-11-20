# Introduction

Container engines (LXC, docker) rely on control groups to account and limit resources.
cgroups is a feature provided by the linux kernel.

```
cid=$(docker run -d cassandra)
ls /sys/fs/cgroup/*/docker/${cid}
```

The memory cgroup accounts and limits RAM usage in units of pages.

```
getconf PAGE_SIZE # 4096

cat /sys/fs/cgroup/memory/docker/${cid}/memory.usage_in_bytes # Is a multiple of 4096
cat /sys/fs/cgroup/memory/docker/${cid}/memory.limit_in_bytes # Unlimited

echo $((3*10**9)) > /sys/fs/cgroup/memory/docker/${cid}/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/docker/${cid}/memory.limit_in_bytes # != 3*10**9

echo $((3*10**30)) > /sys/fs/cgroup/memory/docker/${cid}/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/docker/${cid}/memory.limit_in_bytes # == 3*2**30
```

The kernel will never allow a memory cgroup to grow beyond its limit.

```
cat sys/fs/cgroup/memory/docker/${cid}/memory.failcnt # ==0 The cgroup should not have reached its limit by now
cp /sys/fs/cgroup/memory/docker/${cid}/memory.{max_usage_in_bytes,limit_in_bytes} # Tight fit
docker exec -ti ${cid} cassandra-stress write n=1000000
cat sys/fs/cgroup/memory/docker/${cid}/memory.failcnt # > 0
```

When a cgroup reaches its limit, the kernel will try to move some of its data from memory to disk to make room for the new data.
This process is called the Page Frame Reclaiming Algorithm and it is described in the `mm/vmscan.c` file.
If it fails to free memory, the Out-Of-Memory killer will select a process from cgroup and will kill it.

# The Page Frame Reclaiming Algorithm (PFRA)

![wikipedia](https://en.wikipedia.org/wiki/Page_replacement_algorithm "Page replacement algorithm")

![elixir](https://elixir.free-electrons.com/linux/v4.6 "Linux source code indexer and cross-referencer")

Call stack
```
try_charge                       # Checks if usage is below limit
└─ try_to_free_mem_cgroup_pages  # Configures the struct scan_control sc
   └─ do_try_to_free_pages       # Increases the amount of page scanned if the first iterations were unsuccessful
      └─ shrink_zones            # Loops over memory zones
         └─ shrink_zone          # Loops over cgroups
            └─ shrink_zone_memcg #
               ├─ get_scan_count # Loops over {active,inactive}{anon,cache} lists
               └─ shrink_list    # Shrinks active if inactive list is low
                  ├─ inactive_list_is_low            # Heuristics
                  ├─ shrink_active_list              # Isolates and loops over pages
                  │  ├─ isolate_lru_pages            # Removes pages from the the active list
                  │  ├─ page_referenced              # Check ACCES bit
                  │  └─ move_active_pages_to_lru     # add pages to inactive list (in some rare cases put them in active list)
                  └─ shrink_inactive_list            # 
                     ├─ isolate_lru_pages            # Removes pages from the the inactive list
                     ├─ shrink_page_list             # Loops over isolated pages
                     │  ├─ page_check_references     # Decides to activate, keep or reclaim a page
                     │  │  └─ page_referenced        #
                     │  ├─ mem_cgroup_uncharge_list  # Update cgroup accounting
                     │  └─ free_hot_cold_page_list   # Send pages to the free lists (see mm/page_alloc.c)
                     └─ putback_inactive_pages       # add unreclaimed pages to active or inactive list
```
