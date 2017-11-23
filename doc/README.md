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

## Tracking page movements in lists

`git grep -HnE 'SetPageReferenced|ClearPageReferenced|SetPageActive|ClearPageActive'`

```
mm/vmscan.c:

page_check_references:
800:  referenced_page = TestClearPageReferenced(page);
826:     SetPageReferenced(page);

shrink_page_list:
1219:    SetPageActive(page);

reclaim_clean_pages_from_list:        # Unrelated PFRA entrypoint
1258:       ClearPageActive(page);

putback_inactive_pages:               # if (put_page_testzero(page))
1531:       __ClearPageActive(page);

move_active_pages_to_lru:             # if (put_page_testzero(page))
1751:       __ClearPageActive(page);

shrink_active_list:
1843:    ClearPageActive(page);  /* we are de-activating */
```


```
add_to_page_cache_lru:
mm/filemap.c:718:       SetPageActive(page);     # if   (shadow && workingset_refault(shadow))
mm/filemap.c:721:       ClearPageActive(page);   # if (!(shadow && workingset_refault(shadow)))

pagecache_get_page:
                 :no_page:
                 :
                 :      /* Init accessed so avoid atomic mark_page_accessed later */
                 :      if (fgp_flags & FGP_ACCESSED)
mm/filemap.c:1207:         __SetPageReferenced(page);
```

```
shmem_getpage_gfp:
               :      page = shmem_alloc_page(gfp, info, index);
               :
               :      if (sgp == SGP_WRITE)
mm/shmem.c:1282:        __SetPageReferenced(page);
```

```
__activate_page:
mm/swap.c:266:    SetPageActive(page);

__lru_cache_activate_page:
mm/swap.c:343:       SetPageActive(page);

mark_page_accessed:
               * When a newly allocated page is not yet visible, so safe for non-atomic ops,
mm/swap.c:359: * __SetPageReferenced(page) may be substituted for mark_page_accessed(page).
mm/swap.c:377:    ClearPageReferenced(page);
mm/swap.c:381:    SetPageReferenced(page);

lru_cache_add_anon:
mm/swap.c:406:    ClearPageActive(page);

lru_cache_add_file
mm/swap.c:413:    ClearPageActive(page);

add_page_to_unevictable_list:
mm/swap.c:451: ClearPageActive(page);

lru_cache_add_active_or_unevictable:
mm/swap.c:474:    SetPageActive(page);

lru_deactivate_file_fn:
mm/swap.c:534: ClearPageActive(page);
mm/swap.c:535: ClearPageReferenced(page);

lru_deactivate_fn:
mm/swap.c:568:    ClearPageActive(page);
mm/swap.c:569:    ClearPageReferenced(page);

release_pages:
mm/swap.c:768:    __ClearPageActive(page);
```

```
release_pages:
page_off_lru:
include/linux/mm_inline.h:75:       __ClearPageActive(page);
```

### Unrelated grep results

`get_user_pages()` is a function used in direct I/O operations to pin the userspace memory that is going to be transferred. [kernelnewbies.org](https://kernelnewbies.org/Linux_2_6_27 "Lockless get_user_pages_fast()")
```
arch/mips/mm/gup.c:53:		SetPageReferenced(page);
arch/mips/mm/gup.c:68:	SetPageReferenced(page);
arch/x86/mm/gup.c:73:		ClearPageReferenced(page);
arch/x86/mm/gup.c:139:		SetPageReferenced(page);
arch/x86/mm/gup.c:154:	SetPageReferenced(page);
arch/x86/mm/gup.c:173:		SetPageReferenced(page);
```

Writing to `/proc/[pid]/clear_refs` clears the PG_Referenced and ACCESSED/YOUNG bits which provides a method to measure approximately how much memory a process is using. [man proc](http://man7.org/linux/man-pages/man5/proc.5.html "/proc/[pid]/clear_refs")
```
fs/proc/task_mmu.c:934:		ClearPageReferenced(page);
fs/proc/task_mmu.c:962:		ClearPageReferenced(page);
```

Page migration.
```
mm/migrate.c:539:    SetPageReferenced(newpage);
mm/migrate.c:542: if (TestClearPageActive(page)) {
mm/migrate.c:544:    SetPageActive(newpage);
mm/migrate.c:1811:      if (TestClearPageActive(new_page))
mm/migrate.c:1812:         SetPageActive(page);
```

High level machine check handler. Handles pages reported by the hardware as being corrupted usually due to a multi-bit ECC memory or cache failure.
```
mm/memory-failure.c:536:      ClearPageActive(p);
```

PageSlabPfmemalloc
```
include/linux/page-flags.h:652:  SetPageActive(page);
include/linux/page-flags.h:658:  __ClearPageActive(page);
include/linux/page-flags.h:664:  ClearPageActive(page);
```

# Idle Page Tracking
`git grep -HnE 'set_page_idle|set_page_young|clear_page_idle|clear_page_young'`

```
page_idle_bitmap_{read,write}:
page_idle_clear_pte_refs:
page_idle_clear_pte_refs_one:
mm/page_idle.c:79:    clear_page_idle(page);
mm/page_idle.c:85:    set_page_young(page);

page_idle_bitmap_write:
mm/page_idle.c:187:       set_page_idle(page);
```

From PFRA:
```
page_referenced_one:
mm/rmap.c:931:    clear_page_idle(page);
mm/rmap.c:932:  if (test_and_clear_page_young(page))
```

```
mark_page_accessed:
mm/swap.c:384:    clear_page_idle(page);
```

### Unrelated grep results

`/proc/[pid]/clear_refs`
```
fs/proc/task_mmu.c:933: test_and_clear_page_young(page);
fs/proc/task_mmu.c:961:		test_and_clear_page_young(page);
```

inline.
```
include/linux/page_idle.h:16:static inline void set_page_young(struct page *page)
include/linux/page_idle.h:21:static inline bool test_and_clear_page_young(struct page *page)
include/linux/page_idle.h:31:static inline void set_page_idle(struct page *page)
include/linux/page_idle.h:36:static inline void clear_page_idle(struct page *page)
include/linux/page_idle.h:52:static inline void set_page_young(struct page *page)
include/linux/page_idle.h:57:static inline bool test_and_clear_page_young(struct page *page)
include/linux/page_idle.h:68:static inline void set_page_idle(struct page *page)
include/linux/page_idle.h:73:static inline void clear_page_idle(struct page *page)
include/linux/page_idle.h:86:static inline void set_page_young(struct page *page)
include/linux/page_idle.h:90:static inline bool test_and_clear_page_young(struct page *page)
include/linux/page_idle.h:100:static inline void set_page_idle(struct page *page)
include/linux/page_idle.h:104:static inline void clear_page_idle(struct page *page)
```

page split.
```
mm/huge_memory.c:3148:		set_page_young(page_tail);
mm/huge_memory.c:3150:		set_page_idle(page_tail);
```

migration.
```
mm/migrate.c:557:		set_page_young(newpage);
mm/migrate.c:559:		set_page_idle(newpage);
```

