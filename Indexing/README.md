# DBA Scripts to asisst with Index Structures

## 1. Fragmentation Details

File: `.\FragmentationInfo.sql`

Extracts the index fragmentation greater than the `@MaxFragmentation` variable value for all objects in the current database.

Some of the useful attributes returned are:

* Database Name
* Schema Name
* Table Name
* Index Name
* Index Type (Heap, Clustered, NonClustered)
* Percent Fragmentation
* Page Count
* Record Count
* Statistics Object Name

WARNING: Running this on Production systems during times of high activity could create lock. It is recommended that you monitor activity on your system/s while running this script.
