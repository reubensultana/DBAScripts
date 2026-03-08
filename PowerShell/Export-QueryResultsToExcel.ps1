Clear-Host
Import-Module dbatools,ImportExcel

#region Get list of target SQL Server instances from Central Repository
$DbaInstance = Connect-DbaInstance -SqlInstance "localhost,14331" -Database "SQLMonitor" -TrustServerCertificate

[string] $SqlCmd = "SELECT ([ServerName] + ',' + [SqlTcpPort]) AS [InstanceName] FROM [dbo].[vwMonitoredServers] WHERE [RecordStatus] = 'A' ORDER BY [ServerOrder] ASC, [ServerName] ASC;"
$ServerList = Invoke-DbaQuery -SqlInstance $DbaInstance -Query $SqlCmd -As PSObject

Disconnect-DbaInstance -InputObject $DbaInstance | Out-Null
#endregion

#region Custom list of target SQL Server instances
$CustomServerList = @(
    "Server1,14331",
    "Server2,14332",
    "Server3,14333",
    "Server4,14334",
    "Server5,14335",
)
$ServerList = @()
$CustomServerList | ForEach-Object {
    $ServerList += [PSCustomObject]@{
        InstanceName = $_
    }
}
#endregion

#region Query to be executed - make sure you test this
[string] $ProcessName = "ServerDatabases"
[string] $SqlCmd = "SET NOCOUNT ON;
SELECT 
    CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) AS ServerName,
    [name] AS [DatabaseName],
    SUSER_SNAME([owner_sid]) AS [DatabaseOwner],
    CONVERT(datetime, [create_date]) AS [CreateDate],
    [compatibility_level] AS [CompatibilityLevel],
    COALESCE([collation_name], '') AS [CollationName], 
    [user_access_desc] AS [UserAccess],
    [is_read_only] AS [IsReadOnly],
    [is_auto_close_on] AS [IsAutoClose],
    [is_auto_shrink_on] AS [IsAutoShrink],
    [state_desc] AS [State],
    [is_in_standby] AS [IsInStandby],
    [recovery_model_desc] AS [RecoveryModel],
    [page_verify_option_desc] AS [PageVerifyOption],
    [is_fulltext_enabled] AS [IsFullTextEnabled],
    [is_trustworthy_on] AS [IsTrustworthy]
FROM sys.databases
ORDER BY database_id ASC;"
#endregion

Clear-Host
$FullResults = @()

$ServerList | ForEach-Object {
    Write-Host "Processing $($_.InstanceName)"
    $DbaInstance = Connect-DbaInstance -SqlInstance $($_.InstanceName) -Database "master" -TrustServerCertificate -ErrorAction SilentlyContinue
    if ($null -ne $DbaInstance) {
        $QueryOutput = Invoke-DbaQuery -SqlInstance $DbaInstance -Query $SqlCmd -As PSObject -Verbose

        if ($null -ne $QueryOutput) {
            $FullResults += $QueryOutput
        }
        Disconnect-DbaInstance -InputObject $DbaInstance | Out-Null
    }
}

#region Output Counts
Write-Host "Total target Instances: $($ServerList.Count)"
Write-Host "Total records: $($FullResults.Count)"
#end region

# review results (bear in mind console size vs. data size
$FullResults | Format-Table -AutoSize
# or
$FullResults | Out-GridView

#region Export to Excel
[string] $OutputFilePath = ".\$(ProcessName)_$(Get-Date -Format "yyyyMMdd_HHmmss").xlsx"
$FullResults | Export-Excel -Path $OutputFilePath -AutoSize -FreezeTopRow -BoldTopRow -WorksheetName $ProcessName
#endregion

#region Generate and display file checksum
Get-ChildItem -Path $OutputFilePath | Sort-Object -Property LastWriteTime | `
    Select-Object Name,LastWriteTime,Length,@{name="Hash";expr={[string] ($($(Get-FileHash -Path $($_.FullName) -Algorithm SHA256).Hash))}} | `
        Format-Table -AutoSize
#endregion
