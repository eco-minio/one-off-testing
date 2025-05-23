MinCache feature

Overview
The MinCache is an optional in-memory caching mechanism integrated into MinIO’s drive storage construct, designed to store `xl.meta` metadata for objects on a per-disk basis. It leverages the `bigcache` library to provide a high-performance, sharded, LRU-based cache, reducing disk I/O for frequently accessed metadata, including inline objects. For workloads with heavy GET activity on the same object significant performance benefits can be realized.

Purpose
The primary goal of MinCache is to optimize metadata (xl.meta) read operations in MinIO’s `xlStorage` layer by:
1. Reducing Disk IOPS: Caching `xl.meta` avoids repeated disk reads for metadata, critical for high-troughput workloads.
2. Improving Latency: In-memory access (which is in nano seconds) replaces disk access (which is in µs for NVMes and ms for HDDs) and helps to accelerate operations like `StatObject` or `GetObjectInfo` (including `GetObject` for inlined objects)
3. Supporting Scalability: By offloading metadata IOPS from drives, it enhances performance in multi-client, multi-object scenarios.

Enabling ;MinCache is particularly valuable in environments with:
- High metadata read rates (e.g., listing objects, checking versions, inlined objects contained within metadata).
- NVMe/SSD backends where IOPS are plentiful but latency still matters.
- Erasure-coded setups with frequent small-object operations.
  
Cache utilization
The cache works as a LRU queue, keeping the most recent xl.meta readily available.  iI cache memory becomes full then the least recently used xl.meta will be removed from cache and replaced with the new xl.meta.  The MinIO cache feature will cache metadata including inlined objects that are eligible on the first write. Subsequent GETs of the same object will now be served from cache instead of from disk.

Caching in MinIO works the same from an architecture standpoint as writing objects directly to disk. All objects are still erasure coded and still are written and retrieved in the same fashion. In essence the only difference for cache objects is the medium from which they are served. 

Any modification or mutation of either an object or its metadata (such as adding / removing tags) will evict the existing metadata from cache, replacing it with the new metadata. 

Limitations

1. **Memory Overhead**: Allocated cache is per node total amount of memory allocated is divided by number of disks.  For example, if you provided 80 GB of memory and had 10 disks each disk would GET 8 GB of memory allocated for cache.
2. **Cold Starts**: Cache is empty on restart, requiring disk hits until populated.
3. **Write-Heavy Workloads**: Minimal benefit if metadata reads are rare (cache remains underutilized).
4. **Eviction Risk** per disk cap may evict hot objects in heavy workloads.
5. ** Versioned objects - Only the latest version of a given object can be accessed via cache. Note that for inlined objects, all versions reside within the xl.meta.
6; ** Replication -  Objects will only be put into cache on the sites that have caching enabled. As above, versioned objects will not be cached if they are uploaded with a version ID.

Examples

When updating object tags the workflow is as follows:

- On first PUT the object is written to disk and cache simultaneously.
- The object then has tags applied to it, this replaces the existing version with the new version. Even though the object itself has not changed, the metadata has, therefore, what is in cache is replaced.
- A subsequent GET request or stat request for the object will now be served from the cache.
- If the tags are updated again the existing metadata replaces the old.
- Subsequent GET requests issued to the object will now be served from cache again.

Deleting an object

 A deleted object is removed immediately from cache. Subsequent immediate GET requests will return objects not found as it has been removed both from cache and from the disk.
This includes deletes that happened via ILM or replication rules as well. 

 Restarting a MinIO server

When a given server has been restarted, its current cache content is lost. 
Subsequent PUT or GET requests will be required to repopulate the cache of a given server.

