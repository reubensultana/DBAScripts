# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Unzip-Files.ps1

# unzip files to the current directory and meeting a specific criteria, e.g. ZIP files created since the 15th May 2023
[string] $CreationTime = "2023-05-15"
Get-ChildItem -Filter *.zip | Where-Object -Property CreationTime -ge -Value $CreationTime | ForEach-Object { $Item = New-Item ".\$($_.BaseName)" -ItemType Directory -Force -ErrorAction SilentlyContinue; Expand-Archive -Path $($_.FullName) -Destination ".\$($_.BaseName)\" -Force -ErrorAction SilentlyContinue -Verbose }
