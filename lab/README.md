# NCA

++ nca is reactive:
* it can respond to unpredictable events.
* it can respond to its own mistakes.
* users do not have to tune

-- nca:
* can make the difference between fitting and inactive workloads
* can make predict if pages are going to be usefull
* users can not tune

?? nca:
* I think that fitting workloads could be detected during the reclaim because of the pgactivate++. That information could be used to change the decision during the reclaim to protect the cgroup with the most pgactivated.
* I think only users can predict if pages are going to be usefull (not kernel's job)

nca costs:
* atomic_inc_ret @ pgcharge
* sort containers @ reclaim (array allocation)

nca patch details:
* target_mem_cgroup_only "can" make unecessary extra loops (will not with cgroup v2)
* some dirty useless remaining code 

# IPTB

--iptb is not reactive as nca because it uses monitoring.
It collects stats over a period (10sec here).
But users can use shorter time intervals which would increase the cost of monitoring.

++ iptb has a very low interference with vmscan. (only page locking)

-- iptb uses 2extra bits per page

iptb details:
it could monitor pages of specific cgroups only.

# FS

fs moves pages in the LRU lists at a rate define by users (1MB/s here).
-- fs is not reactive as nca.

-- fs interferes with vmscan (lru locking to isolate pages. moving pages in lru)

++ update lru and its metrics (active,inactive,nr_recent_scanned/nr_recent_rotated)
