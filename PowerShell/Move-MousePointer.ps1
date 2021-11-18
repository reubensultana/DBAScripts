# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Move-MousePointer.ps1

# Does what it says on the lid...

Clear-Host
Write-Host "Moving mouse..."
Add-Type -AssemblyName System.Windows.Forms

# GUI settings
<#
$console = $host.UI.RawUI
$console.WindowTitle = "Mouse Move"
$WindowSize = $console.WindowSize
$WindowSize.Width  = 50
$WindowSize.Height = 10
$host.UI.RawUI.WindowSize = $WindowSize
#>

# the code
[int] $PlusorMinus = 5
[int] $SleepSeconds = 2
while ($true) {
    $p = [System.Windows.Forms.Cursor]::Position
    $x = $p.X + $PlusorMinus
    $y = $p.Y + $PlusorMinus
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
    Start-Sleep -Seconds $SleepSeconds
    $PlusorMinus = -$PlusorMinus
}
