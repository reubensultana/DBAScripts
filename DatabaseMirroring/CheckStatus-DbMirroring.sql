/* Source: https://github.com/reubensultana/DBAScripts/blob/master/DatabaseMirroring/CheckStatus-DbMirroring.sql */

/* NOTE: This script should be run using SQLCMD mode */
:ON ERROR EXIT

:SETVAR SQLServerInstance "localhost,1433"
:SETVAR DatabaseName "master"

:CONNECT $(SQLServerInstance)
USE [$(DatabaseName)]
GO
SELECT 
    d.[name], d.[database_id], dm.[mirroring_role_desc], dm.[mirroring_state_desc], 
    dm.[mirroring_safety_level_desc], dm.[mirroring_partner_name], dm.[mirroring_partner_instance], 
    dm.[mirroing_connection_timeout], dm.[mirroring_witness_name], dm.[mirroring_witness_state_desc]
FROM sys.database_mirroring AS dm
    INNER JOIN sys.databases d ON dm.[database_id] = d.[database_id]
WHERE dm.[mirroring_state_desc] IS NOT NULL
ORDER BY dm.[mirroring_role_desc], d.[name]
GO
