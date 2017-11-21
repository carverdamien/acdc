## Mar 5, 2010: commit 645747462435d84c6c6a64269ed49cc3015f753 

```
vmscan: detect mapped file pages used only once
The VM currently assumes that an inactive, mapped and referenced file page
is in use and promotes it to the active list.

However, every mapped file page starts out like this and thus a problem
arises when workloads create a stream of such pages that are used only for
a short time.  By flooding the active list with those pages, the VM
quickly gets into trouble finding eligible reclaim canditates.  The result
is long allocation latencies and eviction of the wrong pages.

This patch reuses the PG_referenced page flag (used for unmapped file
pages) to implement a usage detection that scales with the speed of LRU
list cycling (i.e.  memory pressure).

If the scanner encounters those pages, the flag is set and the page cycled
again on the inactive list.  Only if it returns with another page table
reference it is activated.  Otherwise it is reclaimed as 'not recently
used cache'.

This effectively changes the minimum lifetime of a used-once mapped file
page from a full memory cycle to an inactive list cycle, which allows it
to occur in linear streams without affecting the stable working set of the
system.

Signed-off-by: Johannes Weiner <hannes@cmpxchg.org>
Reviewed-by: Rik van Riel <riel@redhat.com>
Cc: Minchan Kim <minchan.kim@gmail.com>
Cc: OSAKI Motohiro <kosaki.motohiro@jp.fujitsu.com>
Cc: Lee Schermerhorn <lee.schermerhorn@hp.com>
Signed-off-by: Andrew Morton <akpm@linux-foundation.org>
Signed-off-by: Linus Torvalds <torvalds@linux-foundation.org>
```

```
diff --git a/include/linux/rmap.h b/include/linux/rmap.h
index 72be23b1480a..d25bd224d370 100644
--- a/include/linux/rmap.h
+++ b/include/linux/rmap.h
@@ -209,7 +209,7 @@ static inline int page_referenced(struct page *page, int is_locked,
 				  unsigned long *vm_flags)
 {
 	*vm_flags = 0;
-	return TestClearPageReferenced(page);
+	return 0;
 }
 
 #define try_to_unmap(page, refs) SWAP_FAIL
diff --git a/mm/rmap.c b/mm/rmap.c
index 4d2fb93851ca..fcd593c9c997 100644
--- a/mm/rmap.c
+++ b/mm/rmap.c
@@ -601,9 +601,6 @@ int page_referenced(struct page *page,
 	int referenced = 0;
 	int we_locked = 0;
 
-	if (TestClearPageReferenced(page))
-		referenced++;
-
 	*vm_flags = 0;
 	if (page_mapped(page) && page_rmapping(page)) {
 		if (!is_locked && (!PageAnon(page) || PageKsm(page))) {
diff --git a/mm/vmscan.c b/mm/vmscan.c
index d9a0e0d3aac7..79c809895fba 100644
--- a/mm/vmscan.c
+++ b/mm/vmscan.c
@@ -561,18 +561,18 @@ redo:
 enum page_references {
 	PAGEREF_RECLAIM,
 	PAGEREF_RECLAIM_CLEAN,
+	PAGEREF_KEEP,
 	PAGEREF_ACTIVATE,
 };
 
 static enum page_references page_check_references(struct page *page,
 						  struct scan_control *sc)
 {
+	int referenced_ptes, referenced_page;
 	unsigned long vm_flags;
-	int referenced;
 
-	referenced = page_referenced(page, 1, sc->mem_cgroup, &vm_flags);
-	if (!referenced)
-		return PAGEREF_RECLAIM;
+	referenced_ptes = page_referenced(page, 1, sc->mem_cgroup, &vm_flags);
+	referenced_page = TestClearPageReferenced(page);
 
 	/* Lumpy reclaim - ignore references */
 	if (sc->order > PAGE_ALLOC_COSTLY_ORDER)
@@ -585,11 +585,36 @@ static enum page_references page_check_references(struct page *page,
 	if (vm_flags & VM_LOCKED)
 		return PAGEREF_RECLAIM;
 
-	if (page_mapped(page))
-		return PAGEREF_ACTIVATE;
+	if (referenced_ptes) {
+		if (PageAnon(page))
+			return PAGEREF_ACTIVATE;
+		/*
+		 * All mapped pages start out with page table
+		 * references from the instantiating fault, so we need
+		 * to look twice if a mapped file page is used more
+		 * than once.
+		 *
+		 * Mark it and spare it for another trip around the
+		 * inactive list.  Another page table reference will
+		 * lead to its activation.
+		 *
+		 * Note: the mark is set for activated pages as well
+		 * so that recently deactivated but used pages are
+		 * quickly recovered.
+		 */
+		SetPageReferenced(page);
+
+		if (referenced_page)
+			return PAGEREF_ACTIVATE;
+
+		return PAGEREF_KEEP;
+	}
 
 	/* Reclaim if clean, defer dirty pages to writeback */
-	return PAGEREF_RECLAIM_CLEAN;
+	if (referenced_page)
+		return PAGEREF_RECLAIM_CLEAN;
+
+	return PAGEREF_RECLAIM;
 }
 
 /*
@@ -657,6 +682,8 @@ static unsigned long shrink_page_list(struct list_head *page_list,
 		switch (references) {
 		case PAGEREF_ACTIVATE:
 			goto activate_locked;
+		case PAGEREF_KEEP:
+			goto keep_locked;
 		case PAGEREF_RECLAIM:
 		case PAGEREF_RECLAIM_CLEAN:
 			; /* try to reclaim the page below */
@@ -1359,9 +1386,7 @@ static void shrink_active_list(unsigned long nr_pages, struct zone *zone,
 			continue;
 		}
 
-		/* page_referenced clears PageReferenced */
-		if (page_mapped(page) &&
-		    page_referenced(page, 0, sc->mem_cgroup, &vm_flags)) {
+		if (page_referenced(page, 0, sc->mem_cgroup, &vm_flags)) {
 			nr_rotated++;
 			/*
 			 * Identify referenced, file-backed active pages and
```

## Oct 26, 2010: commit 2e30244a7cc1ff09013a1238d415b4076406388e

```
vmscan,tmpfs: treat used once pages on tmpfs as used once
When a page has PG_referenced, shrink_page_list() discards it only if it
is not dirty.  This rule works fine if the backing filesystem is a regular
one.  PG_dirty is a good signal that the page was used recently because
the flusher threads clean pages periodically.  In addition, page writeback
is costlier than simple page discard.

However, when a page is on tmpfs this heuristic doesn't work because
flusher threads don't write back tmpfs pages.  Consequently tmpfs pages
always rotate around the lru twice at least and adds unnecessary lru
churn.  Simple tmpfs streaming io shouldn't cause large anonymous page
swap-out.

Remove this unncessary reclaim bonus of tmpfs pages.

Signed-off-by: KOSAKI Motohiro <kosaki.motohiro@jp.fujitsu.com>
Cc: Hugh Dickins <hughd@google.com>
Reviewed-by: Johannes Weiner <hannes@cmpxchg.org>
Reviewed-by: Rik van Riel <riel@redhat.com>
Cc: Minchan Kim <minchan.kim@gmail.com>
Signed-off-by: Andrew Morton <akpm@linux-foundation.org>
Signed-off-by: Linus Torvalds <torvalds@linux-foundation.org>
```

```
diff --git a/mm/vmscan.c b/mm/vmscan.c
index 30fd658bb289..b8a6fdc21312 100644
--- a/mm/vmscan.c
+++ b/mm/vmscan.c
@@ -651,7 +651,7 @@ static enum page_references page_check_references(struct page *page,
        }

        /* Reclaim if clean, defer dirty pages to writeback */
-       if (referenced_page)
+       if (referenced_page && !PageSwapBacked(page))
                return PAGEREF_RECLAIM_CLEAN;

        return PAGEREF_RECLAIM;
```

## May 30, 2012: commit e48982734ea0500d1eba4f9d96195acc5406cad6

```
mm: consider all swapped back pages in used-once logic
Commit 6457474 ("vmscan: detect mapped file pages used only once")
made mapped pages have another round in inactive list because they might
be just short lived and so we could consider them again next time.  This
heuristic helps to reduce pressure on the active list with a streaming
IO worklods.

This patch fixes a regression introduced by this commit for heavy shmem
based workloads because unlike Anon pages, which are excluded from this
heuristic because they are usually long lived, shmem pages are handled
as a regular page cache.

This doesn't work quite well, unfortunately, if the workload is mostly
backed by shmem (in memory database sitting on 80% of memory) with a
streaming IO in the background (backup - up to 20% of memory).  Anon
inactive list is full of (dirty) shmem pages when watermarks are hit.
Shmem pages are kept in the inactive list (they are referenced) in the
first round and it is hard to reclaim anything else so we reach lower
scanning priorities very quickly which leads to an excessive swap out.

Let's fix this by excluding all swap backed pages (they tend to be long
lived wrt.  the regular page cache anyway) from used-once heuristic and
rather activate them if they are referenced.

The customer's workload is shmem backed database (80% of RAM) and they
are measuring transactions/s with an IO in the background (20%).
Transactions touch more or less random rows in the table.  The
transaction rate fell by a factor of 3 (in the worst case) because of
commit 6457474.  This patch restores the previous numbers.

Signed-off-by: Michal Hocko <mhocko@suse.cz>
Acked-by: Johannes Weiner <hannes@cmpxchg.org>
Cc: Mel Gorman <mel@csn.ul.ie>
Cc: Minchan Kim <minchan@kernel.org>
Cc: KAMEZAWA Hiroyuki <kamezawa.hiroyu@jp.fujitsu.com>
Reviewed-by: Rik van Riel <riel@redhat.com>
Cc: <stable@vger.kernel.org>	[2.6.34+]
Signed-off-by: Andrew Morton <akpm@linux-foundation.org>
Signed-off-by: Linus Torvalds <torvalds@linux-foundation.org>
```

```
diff --git a/mm/vmscan.c b/mm/vmscan.c
index 44f04364a304..67a4fd4792de 100644
--- a/mm/vmscan.c
+++ b/mm/vmscan.c
@@ -657,7 +657,7 @@ static enum page_references page_check_references(struct page *page,
 		return PAGEREF_RECLAIM;
 
 	if (referenced_ptes) {
-		if (PageAnon(page))
+		if (PageSwapBacked(page))
 			return PAGEREF_ACTIVATE;
 		/*
 		 * All mapped pages start out with page table
```
