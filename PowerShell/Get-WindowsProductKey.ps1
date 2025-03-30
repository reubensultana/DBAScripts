# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-WindowsProductKey.ps1

# Find Windows Product Key
wmic path softwarelicensingservice get OA3xOriginalProductKey
