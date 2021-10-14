/* Source: https://github.com/reubensultana/DBAScripts/blob/master/Audit+Security/GetInfo-PasswordAge.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,1433"

:CONNECT $(SQLServerInstance)
USE [master]
GO
WITH cteLogins AS (
    SELECT
        DATEDIFF(dd, CAST(LOGINPROPERTY([name], 'PasswordLastSetTime') AS datetime), CURRENT_TIMESTAMP) AS [PasswordAge]
        ,[name] AS [LoginName]
    FROM [sys].[sql_logins]
    WHERE [principal_id] > 1 AND [name] NOT LIKE '##MS%' AND [is_expiration_checked] = 0
),
ctePasswordAge AS (
    SELECT 
        COUNT(*) AS [TotalNumber]
        ,(CASE WHEN [PasswordAge] BETWEEN 0 AND 90 THEN COUNT(*) ELSE 0 END) AS [0-90]
        ,(CASE WHEN [PasswordAge] BETWEEN 90 AND 180 THEN COUNT(*) ELSE 0 END) AS [91-180]
        ,(CASE WHEN [PasswordAge] BETWEEN 181 AND 365 THEN COUNT(*) ELSE 0 END) AS [181-365]
        ,(CASE WHEN [PasswordAge] >= 366 THEN COUNT(*) ELSE 0 END) AS [366+]
    FROM cteLogins
    GROUP BY [PasswordAge]
)
SELECT 
    @@SERVERNAME AS [ServerName]
    ,COALESCE([TotalNumber], 0) AS [TotalNumber]
    ,COALESCE([0-90], 0) AS [0-90]
    ,COALESCE([91-180], 0) AS [91-180]
    ,COALESCE([181-365], 0) AS [181-365]
    ,COALESCE([366+], 0) AS [366+]
FROM ctePasswordAge;
GO
