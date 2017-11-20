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
