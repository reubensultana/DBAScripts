# Filter Out SQL Server Error Log Messages

The script will copy the contents of the ERRORLOG file defined by the `@FileNumber` variable into a Temporary Table, then return the results **excluding** the items defined in the `#logexclusions` table.

This script will filter out "noise" messages and allow a DBA to focus on the important items, such as a Deadlock Graph for starters.

The `@ShowSummary` variable will show aggregates for each DISTINCT message as a second result set.

Note that performance might suffer with larger ERRORLOG files. You can check the size of each file using the **undocumented** stored procedure `xp_enumerrorlogs`.
