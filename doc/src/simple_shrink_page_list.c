/* Simplified contextual shrink_page_list() */
static unsigned long shrink_page_list(struct list_head *page_list) {
	LIST_HEAD(ret_pages);
	LIST_HEAD(free_pages);

	while (!list_empty(page_list)) {

		page = lru_to_page(page_list);
		list_del(&page->lru);

		if (!trylock_page(page))
			goto keep;

		if (!force_reclaim)
			references = page_check_references(page, sc);

		switch (references) {
		case PAGEREF_ACTIVATE:
			goto activate_locked;
		case PAGEREF_KEEP:
			goto keep_locked;
		case PAGEREF_RECLAIM:
		case PAGEREF_RECLAIM_CLEAN:
			; /* try to reclaim the page below */
		}

		list_add(&page->lru, &free_pages);
		continue;

activate_locked:
		SetPageActive(page);
keep_locked:
		unlock_page(page);
keep:
		list_add(&page->lru, &ret_pages);
	}

	mem_cgroup_uncharge_list(&free_pages);
	free_hot_cold_page_list(&free_pages, true);

	list_splice(&ret_pages, page_list);
	return nr_reclaimed;
}
