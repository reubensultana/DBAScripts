<#
    .SYNOPSIS
    Collect counters required for SQL Server Performance Monitoring and log as CSV.

    .DESCRIPTION
    Collect counters required for SQL Server Performance Monitoring and log as CSV. 
    Default log file location is C:\TEMP\sql-perfmon_yyyyMMddHHmmss.csv.
    Counters are collected at 1 second intervals for 1 hour or 3600 seconds.
    No support or warranty is supplied or inferred. 
    Use at your own risk.

    .PARAMETER DestinationFolder
    Location where the output file will be saved. The default is "C:\TEMP"

    .PARAMETER MaxSamples
    Specifies the number of samples to get from each counter. The default is 1 sample.
        
    .PARAMETER SampleInterval
    Specifies the time between samples in seconds. The minimum value is 1 second and the default value is 1 hour (3600 seconds).

    .INPUTS
    Parameters above.
    
    .OUTPUTS
    None.

    .NOTES
    Version: 1.0
        Creation Date: May 1, 2015
        Modified Date: June 17, 2016
        Author: Justin Henriksen ( http://justinhenriksen.wordpress.com )
    Version: 1.1
        Modified Date: June 08, 2017
        Author: Reuben Sultana ( http://reubensultana.com )

#>
param([String]$DestinationFolder = 'C:\Temp\',
	  [int32]$SampleInterval = 1,
      [int32]$MaxSamples = 3600
)

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# NOTE: Counter names MUST be exact otherwise it won't work
$counters = @(
	"\Memory\Available MBytes", 
	
	"\PhysicalDisk(_Total)\Avg. Disk sec/Read", 
	"\PhysicalDisk(_Total)\Avg. Disk sec/Write", 
	"\PhysicalDisk(_Total)\Disk Reads/sec", 
	"\PhysicalDisk(_Total)\Disk Writes/sec", 
	
	"\PhysicalDisk(1 L:)\Avg. Disk sec/Read", 
	"\PhysicalDisk(1 L:)\Avg. Disk sec/Write", 
	"\PhysicalDisk(1 L:)\Disk Reads/sec", 
	"\PhysicalDisk(1 L:)\Disk Writes/sec", 
	
	"\PhysicalDisk(2 S:)\Avg. Disk sec/Read", 
	"\PhysicalDisk(2 S:)\Avg. Disk sec/Write", 
	"\PhysicalDisk(2 S:)\Disk Reads/sec", 
	"\PhysicalDisk(2 S:)\Disk Writes/sec",
	
	"\Processor(_Total)\% Processor Time",
	
	"\SQLServer:General Statistics\User Connections",
	
	"\SQLServer:Memory Manager\Memory Grants Pending",
	
	"\SQLServer:SQL Statistics\Batch Requests/sec",
	"\SQLServer:SQL Statistics\SQL Compilations/sec",
	"\SQLServer:SQL Statistics\SQL Re-compilations/sec",
	
	"\System\Processor Queue Length"
)


$FileName = "sql-perfmon_$(Get-Date -f "yyyyMMddHHmmss")"
$FileExtension = "csv"

if (Test-Path $DestinationFolder) {
    Clear-Host
    Write-Output "Collecting counters..."
    Write-Output "Press Ctrl+C to exit."

    $FilePath = $DestinationFolder + $FileName + "." + $FileExtension

    try {
        Get-Counter -Counter $counters -SampleInterval $SampleInterval -MaxSamples $MaxSamples | 
            Export-Counter -FileFormat $FileExtension -Path $FilePath -Force
    }
    catch {
        Clear-Host
        Write-Warning "Could not start collection for specified counters"
    }
}
