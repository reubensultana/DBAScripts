# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Clean-TempDirectories.ps1

# clean up all TEMP directories
@(
    "$($env:TEMP)"
    "$($env:TMP)"
    "$($env:windir)\Temp"
    "$($env:localappdata)\Temp"
) | ForEach-Object { Get-ChildItem -Path $_ -Recurse -ErrorAction SilentlyContinue | Remove-Item -Recurse -ErrorAction SilentlyContinue -Verbose }
