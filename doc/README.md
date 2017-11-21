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

See [wikipedia](https://en.wikipedia.org/wiki/Page_replacement_algorithm "Page replacement algorithm") for a quick introduction.

## Simplified call stack

Browse Linux v6.0 on [elixir.free-electrons.com](https://elixir.free-electrons.com/linux/v4.6/source "Linux source code indexer and cross-referencer")

```
try_charge                        # Checks if usage is below limit before triggering the PFRA (see mm/memcontrol.c)
│
└─ try_to_free_mem_cgroup_pages   # Configures the struct scan_control sc
   └─ do_try_to_free_pages        # Increases the amount of page scanned if the first iterations were unsuccessful
      └─ shrink_zones             # Loops over memory zones
         └─ shrink_zone           # Loops over cgroups
            │
            └─ shrink_zone_memcg  # Loops over {active,inactive}{anon,cache} lists of a given cgroup
               ├─ get_scan_count  # Heuristics to decide how many pages should be scanned in each list
               └─ shrink_list     # Shrinks active if inactive list is low
                  │
                  ├─ inactive_list_is_low         # Heuristics to protect the active list
                  ├─ shrink_active_list           # Isolates and loops over pages
                  │  ├─ isolate_lru_pages         # Removes pages from the the active list
                  │  ├─ page_referenced           # Check ACCES bit in the page table entries
                  │  └─ move_active_pages_to_lru  # Add pages to inactive list (in some rare cases put them in active list)
                  │
                  └─ shrink_inactive_list
                     ├─ isolate_lru_pages            # Removes pages from the the inactive list
                     ├─ shrink_page_list             # Loops over isolated pages
                     │  ├─ page_check_references     # Decides to activate, keep or reclaim a page
                     │  │  └─ page_referenced
                     │  ├─ mem_cgroup_uncharge_list  # Update cgroup accounting
                     │  └─ free_hot_cold_page_list   # Send pages to the free lists (see mm/page_alloc.c)
                     └─ putback_inactive_pages       # Add unreclaimed pages to active or inactive list
```

## Tracking pages movements in lists

```
arch/mips/mm/gup.c:		SetPageReferenced(page);
arch/mips/mm/gup.c:	SetPageReferenced(page);
arch/x86/mm/gup.c:		SetPageReferenced(page);
arch/x86/mm/gup.c:	SetPageReferenced(page);
arch/x86/mm/gup.c:		SetPageReferenced(page);
mm/filemap.c:			__SetPageReferenced(page);
mm/migrate.c:		SetPageReferenced(newpage);
mm/shmem.c:			__SetPageReferenced(page);
mm/swap.c: * __SetPageReferenced(page) may be substituted for mark_page_accessed(page).
mm/swap.c:		SetPageReferenced(page);
mm/vmscan.c:		SetPageReferenced(page);
arch/x86/mm/gup.c:		ClearPageReferenced(page);
fs/proc/task_mmu.c:		ClearPageReferenced(page);
fs/proc/task_mmu.c:		ClearPageReferenced(page);
mm/swap.c:		ClearPageReferenced(page);
mm/swap.c:	ClearPageReferenced(page);
mm/swap.c:		ClearPageReferenced(page);
mm/vmscan.c:	referenced_page = TestClearPageReferenced(page);
include/linux/page-flags.h:	SetPageActive(page);
mm/filemap.c:			SetPageActive(page);
mm/migrate.c:		SetPageActive(newpage);
mm/migrate.c:			SetPageActive(page);
mm/swap.c:		SetPageActive(page);
mm/swap.c:			SetPageActive(page);
mm/swap.c:		SetPageActive(page);
mm/vmscan.c:		SetPageActive(page);
include/linux/mm_inline.h:			__ClearPageActive(page);
include/linux/page-flags.h:	__ClearPageActive(page);
include/linux/page-flags.h:	ClearPageActive(page);
mm/filemap.c:			ClearPageActive(page);
mm/memory-failure.c:		ClearPageActive(p);
mm/migrate.c:	if (TestClearPageActive(page)) {
mm/migrate.c:		if (TestClearPageActive(new_page))
mm/swap.c:		ClearPageActive(page);
mm/swap.c:		ClearPageActive(page);
mm/swap.c:	ClearPageActive(page);
mm/swap.c:	ClearPageActive(page);
mm/swap.c:		ClearPageActive(page);
mm/swap.c:		__ClearPageActive(page);
mm/vmscan.c:			ClearPageActive(page);
mm/vmscan.c:			__ClearPageActive(page);
mm/vmscan.c:			__ClearPageActive(page);
mm/vmscan.c:		ClearPageActive(page);	/* we are de-activating */
```
