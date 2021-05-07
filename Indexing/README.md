# DBA Scripts to assist with Index Structures

## 1. Fragmentation Details

File: `.\FragmentationInfo.sql`

Extracts the index fragmentation greater than the `@MaxFragmentation` variable value for all objects in the current database.

Some of the useful attributes returned are:

* Server Name
* Database Name
* Schema Name
* Table Name
* Index Name
* Index Type (Heap, Clustered, NonClustered)
* Percent Fragmentation
* Page Count
* Record Count
* Statistics Object Name
* Last Updated
* Number of Rows in the Base Table
* Number of Rows Sampled (by the last UPDATE STATISTICS operation)
* Number of Rows Modified (since the last UPDATE STATISTICS operation)
* Sample Size as a Percentage
* Timestamp

Limits results to identified Indexes and Statistics only; excludes Auto-Generated Statistics.

## 2. Statistics Information

File: `.\StatisticsInfo.sql`

Extracts detailsabout all Statistics objects for a specific database.

Attributes retruned are:

* Server Name
* Database Name
* Schema Name
* Table Name
* Statistics Object Name
* Last Updated
* Number of Rows in the Base Table
* Number of Rows Sampled (by the last UPDATE STATISTICS operation)
* Number of Rows Modified (since the last UPDATE STATISTICS operation)
* Sample Size as a Percentage
* Timestamp

Excludes System objects, Tables which have not been modified, Auto-Generated Statistics, and Statistics which have a 100 Percent Sample Rate.

## 3. Generate Indexes Script 2008 - CREATE

File: `.\Generate Indexes Script 2008 - CREATE.sql`

Script, originally written for SQL Server 2008, to reverse-engineer `CREATE` statements for all Indexes.

## 4. Generate Indexes Script 2008 - DROP

File: `.\Generate Indexes Script 2008 - DROP.sql`

Script, originally written for SQL Server 2008, to reverse-engineer `DROP` statements for all Indexes.

-----

&nbsp;

WARNING: Running any of these scripts on Production systems during times of high activity could create locks. It is recommended that you monitor activity on your system/s while running these scripts.
