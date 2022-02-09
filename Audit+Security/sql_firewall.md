# Creating a SQL Firewall

## Requirements

The idea of a SQL Firewall came to me a number of years ago, probably sometime around 2008, and however I have not given it much thought since.  It has come up a number of times in discussions with colleagues, managers, and clients however the discussions did not move further.

The topic has recently come up again, and I was presented with an actual use-case, so I decided to delve into this further and gauge the feasibility.

The solution would have to be designed and developed, then tested to ensure that it did not have any impact on performance, and of course that it does "what it says on the tin".

## Use Case

The scenario was suggested by someone I know who works as an IT Auditor. They wanted to know whether, when  accessing a SQL Server instance, Logins (SQL or Windows) can be restricted to a specific list of Hosts (or IP addresses).  Those working with Firewalls and Access Control Lists (ACLs) are familiar with this concept.

## Proposal

There are a number of ways that a technical implementation can be done. All of them revolve around a [Logon Trigger](https://docs.microsoft.com/en-us/sql/relational-databases/triggers/logon-triggers) working around a Table, created in the MASTER database, and which would store the mappings between Logins and the Hosts, or rather the IP addresses since the Host Name can be defined as part of the [connection string](https://www.connectionstrings.com/sql-server/) - see [Workstation ID (or WSID)](https://docs.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnection.workstationid) in the [SqlConnection.ConnectionString Property](https://docs.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnection.connectionstring) reference document or the documentation for the [HOST_NAME](https://docs.microsoft.com/en-us/sql/t-sql/functions/host-name-transact-sql) function.

An Access Control List (ACL) would contain a list of Logins and the IP addresses from where they are allowed to or blocked  from accessing the SQL Server instance. The ACL would provide flexibility in that it would allow an Administrator to control who can or cannot connect. This also leads to increased overheads since the Logins would have to be maintained (i.e. every time a Login is created/deleted) and Login-Host mappings would have to exist for all possible combinations (e.g. an Organisation where Users do not have a fixed desk/location).

This approach would also allow Admins to create restrictions, that is, from where a Login _cannot_ connect. Of course, a larger number of entries could lead to increased performance overheads.

On the other hand, an Allow List (AL) would be a simpler approach, requiring the least number of records  since we are only storing who can connect and from where. This was the selected approach.

## Implementation

As mentioned above, the AL Table contains the Long-Host mapping, hence when the Login Trigger fires the code would:

1. check whether the Login exists in the Table
   Uses the [ORIGINAL_LOGIN()](https://docs.microsoft.com/en-us/sql/t-sql/functions/original-login-transact-sql) and [SYSTEM_USER](https://docs.microsoft.com/en-us/sql/t-sql/functions/system-user-transact-sql) functions

2. check the source IP Address against the one stored
   Originally this was being extracted from the `client_net_address` column of the [sys.dm_exec_connections](https://docs.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-connections-transact-sql) Dynamic Management View. This however required the `VIEW SERVER STATE` permission, which might not be granted to all Logins due to security restrictions.
   An alternative, and quite possibly a better one because it does not require accessing a DMV, is [using the EVENTDATA() function](https://docs.microsoft.com/en-us/sql/relational-databases/triggers/capture-logon-trigger-event-data). In a nutshell, this returns an XML structure which would have to be "shred" in order to extract the "ClientHost" property value. The intermediate results of the `EVENTDATA()` function are being stored in a XML variable, then querying that variable for the "ClientHost" property.

That's it. So if the first condition is not met this means that the Login does not have any restrictions and the connection is allowed.

If on the other hand the first condition is met and the second is not, then the connection is dropped.

If any of the rules need to be "disabled", we can simply delete the record from the Table, thus ensuring that the data remains valid and trim.

## Final Thoughts

When a Login attempt fails, due to the above conditions being met, the End User will get the following error message:

```text
Logon failed for login '<LOGIN_NAME>' due to trigger execution.
```

This is a standard message and cannot be replace by a friendlier one, such as to inform the End User that they are not allowed to connect from that specific Workstation/Host for example.

The Logon Trigger will however write the `RAISERROR` message to the SQL Server ERRORLOG, which can then be used for analysis and troubleshooting. A sample of the messgae is shown below:

``` text
Failed connection attempt for <Login_Name> from <Host_Name>
Error: 3609, Severity: 16, State: 2.
The transaction ended in the trigger. The batch has been aborted.
Error: 17892, Severity: 20, State: 1.
Logon failed for login '<Login_Name>' due to trigger execution. [CLIENT: <IP_Address>]
```

The solution will not work with Active Directory Groups since the Group Name cannot be retrieved when a connection is attempted. Implementing such a feature would require additional permissions and would also incur increased performance overheads.

Finally, it is highly recommended that the Login-Host mappings for every SQL Server instance are are stored in an alternate location - a source-control system might just do the trick, with the audit trail providing evidence should this be required.
