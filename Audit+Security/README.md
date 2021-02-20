# DBA Scripts for Audit and Security

## 1. Server Configuration Audit as XML

File: `.\Server Configuration Audit as XML.sql` and `.\Server Configuration Audit as XML - Azure.sql`

Extracts the Server COnfiguration and presents it as an XML document. This can be used for periodic configuration snapshots, or to deliver a snapshot of the configuration to third-parties (e.g. Project Teams, Vendors, etc.) for their own audit or documentation requireemnts.

The various configuration data sets retrieved are listed below. This information is retrieved from a combination of the `master.dbo.xp_msver` and `master.dbo.xp_instance_regread` stored procedures, or the `SERVERPROPERTY` function.

1. Server Name
2. Host Machine Name
3. Product Version
4. Engine Edition
5. Instance Collation
6. Character Set Name
7. Sort Order Name
8. Default Data File Path
9. Default Log File Path
10. Integrated Security options
11. Full Text installation sttatus
12. Whether the Instance is Clustered
13. CLR Version
14. Server Authentication allowed (description)
15. Instance Installation Root Folder
16. Instance Installation Language
17. Number of Logical Processors available
18. OS Version
19. Total amount of Memory in MB
20. Date when the last Servie Pack/Update/Patch/CU was installed
21. Lists of:
    1. Active Endpoints/Listeners (unique values from the `sys.dm_exec_connections` DMV)
    2. Values from the `sys.configurations` table
    3. Databases, including all columns from the `sys.databases` DMV
    4. Database Files, including all columns from the `sys.master_files` DMV
    5. Server Principals, including all columns from the `sys.server_principals` DMV
    6. Credentials, including all columns from the `sys.credentials` DMV
    7. Server Audits, including all columns from the `sys.server_audits` DMV
    8. Server Audit Specifications, including all columns from the `sys.server_audit_specifications` DMV
    9. Server Audit Specification Details, including all columns from the `sys.server_audit_specification_details` DMV
    10. Mail Profile, including all columns from the `msdb.dbo.sysmailprofile` table
    11. Mail Account, including all columns from the `msdb.dbo.stsmail_account` table
    12. Agent Jobs, including all columns from the `msdb.dbo.sysjobs` table
    13. Agent Job Steps, including all columns from the `msdb.dbo.sysjobsteps` table
    14. Agent Operators, including all columns from the `msdb.dbo.sysoperators` table
    15. Agent Alerts, including all columns from the `msdb.dbo.sysalerts` table
    16. Endpoints, including all columns from the `sys.endpoints` DMV
    17. Linked Servers, including all columns from the `sys.servers` table
    18. Availability Group Databases, including all columns from the `sys.availability_databases_cluster` DMV
    19. Availability Group Listener IPs, including all columns from the `sys.availability_group_listener_ip_addresses` DMV
    20. Availability Group Listeners, including all columns from the `sys.availability_group_listeners` DMV
    21. Availability Groups, including all columns from the `sys.availability_groups` DMV
    22. Availability Groups Cluster, including all columns from the `sys.availability_groups_cluster` DMV
    23. Availability Group Read-Only Routing, including all columns from the `sys.availability_read_only_routing_lists` DMV
    24. Availability Group Replicas, including all columns from the `sys.availability_replicas` DMV
22. The `CURRENT_TIMESTAMP` value when this configuration data was extracted.

The script has also been adapted for Azure, indicated by the file name.

## 2. Report Server-level and Database-level permissions for a User

File: `.\Report Server-level and Database-level permissions for a User.sql`

Provides a snapshot of permissions granted to Logins and Users on one or all Databases.  
The output can be multiple result sets which can then for example be copied to an Excel spreadsheet, or you can output the entire results as a XML struture.  

The result sets provided are:

1. Server Name
2. Server Permissions
3. Server Role Membership
4. Database Object Permissions
5. Users and Schemas
6. Database Role Memebership (incl. nested roles)
7. Inherited Permissions
8. Permissions in the SSISDB database
9. SQL Agent Job Ownership
10. Database Ownership
11. The `CURRENT_TIMESTAMP` value the report was run.

Most of the above will provide the TSQL to `CREATE`/`DROP` or `GRANT`/`REVOKE`/`DENY` the permissions reported. This allows for quick clean up of a Login permissions, or the scripts can be used to replicate the Login permissions onto another (some string manipulation may be necessary).

## 3. Track Database Code Changes

File: `.\Track Database Code Changes.sql`

A sample script to implement basic schema changes auditing to a single database.

The code creates a Table and a Database Trigger which will be used to capture and store the relevant information.

Note that the Logins would have to be granted the `VIEW SERVER STATE` permission in order to collect the IP address.  Remove this if this does not suit your security design.
