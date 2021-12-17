# --------------------------------------------------
# Using Powershell - administrator mode:
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# --------------------------------------------------

# --- Uninstall unecessary applications that come with Windows out of the box ---
# 3D Builder
Get-AppxPackage Microsoft.3DBuilder | Remove-AppxPackage | Out-Null
# Autodesk
Get-AppxPackage *Autodesk* | Remove-AppxPackage | Out-Null
# Bing Weather, News, Sports, and Finance (Money):
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage | Out-Null
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage | Out-Null
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage | Out-Null
Get-AppxPackage Microsoft.BingWeather | Remove-AppxPackage | Out-Null
# BubbleWitch
Get-AppxPackage *BubbleWitch* | Remove-AppxPackage | Out-Null
# Candy Crush
Get-AppxPackage king.com.CandyCrush* | Remove-AppxPackage | Out-Null
# Comms Phone
Get-AppxPackage Microsoft.CommsPhone | Remove-AppxPackage | Out-Null
# Dropbox
Get-AppxPackage *Dropbox* | Remove-AppxPackage | Out-Null
# Facebook
Get-AppxPackage *Facebook* | Remove-AppxPackage | Out-Null
# Keeper
Get-AppxPackage *Keeper* | Remove-AppxPackage | Out-Null
# March of Empires
Get-AppxPackage *MarchofEmpires* | Remove-AppxPackage | Out-Null
# Minecraft
Get-AppxPackage *Minecraft* | Remove-AppxPackage | Out-Null
# Netflix
Get-AppxPackage *Netflix* | Remove-AppxPackage | Out-Null
# Office Hub
Get-AppxPackage Microsoft.MicrosoftOfficeHub | Remove-AppxPackage | Out-Null
# One Connect
Get-AppxPackage Microsoft.OneConnect | Remove-AppxPackage | Out-Null
# OneNote
Get-AppxPackage Microsoft.Office.OneNote | Remove-AppxPackage | Out-Null
# Plex
Get-AppxPackage *Plex* | Remove-AppxPackage | Out-Null
# Skype (Metro version)
Get-AppxPackage Microsoft.SkypeApp | Remove-AppxPackage | Out-Null
# Solitaire
Get-AppxPackage *Solitaire* | Remove-AppxPackage | Out-Null
# Sway
Get-AppxPackage Microsoft.Office.Sway | Remove-AppxPackage | Out-Null
# Twitter
Get-AppxPackage *Twitter* | Remove-AppxPackage | Out-Null
# Xbox
Get-AppxPackage Microsoft.XboxApp | Remove-AppxPackage | Out-Null
Get-AppxPackage Microsoft.XboxIdentityProvider | Remove-AppxPackage | Out-Null
# Zune Music, Movies & TV
Get-AppxPackage Microsoft.ZuneMusic | Remove-AppxPackage | Out-Null
Get-AppxPackage Microsoft.ZuneVideo | Remove-AppxPackage | Out-Null

# --- Other ---
# Alarms
Get-AppxPackage Microsoft.WindowsAlarms | Remove-AppxPackage | Out-Null
# Feedback Hub
Get-AppxPackage Microsoft.WindowsFeedbackHub | Remove-AppxPackage | Out-Null
# Get Started
Get-AppxPackage Microsoft.Getstarted | Remove-AppxPackage | Out-Null
# Mail & Calendar
Get-AppxPackage microsoft.windowscommunicationsapps | Remove-AppxPackage | Out-Null
# Maps
Get-AppxPackage Microsoft.WindowsMaps | Remove-AppxPackage | Out-Null
# Messaging
Get-AppxPackage Microsoft.Messaging | Remove-AppxPackage | Out-Null
# People
Get-AppxPackage Microsoft.People | Remove-AppxPackage | Out-Null
# Phone
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage | Out-Null
# Photos
Get-AppxPackage Microsoft.Windows.Photos | Remove-AppxPackage | Out-Null
# Sound Recorder
Get-AppxPackage Microsoft.WindowsSoundRecorder | Remove-AppxPackage | Out-Null
# Sticky Notes
Get-AppxPackage Microsoft.MicrosoftStickyNotes | Remove-AppxPackage | Out-Null

# --- Windows Settings ---
# Privacy: Let apps use my advertising ID: Disable
If (-Not (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo")) {
    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo | Out-Null
}
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo -Name Enabled -Type DWord -Value 0 | Out-Null
# Start Menu: Disable Bing Search Results
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search -Name BingSearchEnabled -Type DWord -Value 0 | Out-Null
# To Restore (Enabled):
# Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search -Name BingSearchEnabled -Type DWord -Value 1 | Out-Null

# Disable Telemetry (requires a reboot to take effect)
# Note this may break Insider builds for your organization
# Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Type DWord -Value 0 | Out-Null
# Get-Service DiagTrack,Dmwappushservice | Stop-Service | Set-Service -StartupType Disabled | Out-Null

# Change Explorer home screen back to "This PC"
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Type DWord -Value 1 | Out-Null
# Change it back to "Quick Access" (Windows 10 default)
# Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Type DWord -Value 2 | Out-Null

# These make "Quick Access" behave much closer to the old "Favorites"
# Disable Quick Access: Recent Files
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 0 | Out-Null
# Disable Quick Access: Frequent Folders
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 0 | Out-Null
# To Restore:
# Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 1 | Out-Null
# Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 1 | Out-Null

# Disable Xbox Gamebar
Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name AppCaptureEnabled -Type DWord -Value 0 | Out-Null
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name GameDVR_Enabled -Type DWord -Value 0 | Out-Null

# Turn off People in Taskbar
If (-Not (Test-Path "HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People")) {
    New-Item -Path HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People | Out-Null
}
Set-ItemProperty -Path "HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name PeopleBand -Type DWord -Value 0 | Out-Null


# https://chocolatey.org/
# base
choco install chocolatey -y
#--- Windows Subsystems/Features ---
choco install Microsoft-Hyper-V-All -source windowsFeatures
choco install Microsoft-Windows-Subsystem-Linux -source windowsfeatures
# packages from https://community.chocolatey.org/packages
# security
# choco install malwarebytes -y
choco install keepass -y
choco install lastpass -y
# basics
choco install javaruntime -y
# choco install googlechrome -y # download and install from Google
# choco install googledrive -y # download and install from Google
choco install 7zip.install -y
choco install notepadplusplus.install -y
choco install foxitreader -y
choco install wps-office-free -y
# social
choco install skype -y
choco install zoom -y
choco install zoom-client -y
choco install microsoft-teams -y
choco install microsoft-teams.install -y # Machine-Wide Install
choco install webex-meetings -y
# media
choco install paint.net -y
choco install audacity -y
choco install k-litecodecpackfull -y
# choco install spotify -y # or install through Microsoft Store
choco install obs-studio -y
choco install obs-virtualcam -y
choco install shotcut -y
choco install shotcut.install -y
choco install virtualdub2 -y
choco install vlc -y
# dev
choco install mremoteng -y
choco install sql-server-management-studio -y
choco install powershell-core -y
choco install vscode -y
choco install vscode.install -y
# choco install vscode-powershell -y # or install as an extension below
choco install vscode-settingssync -y
choco install azure-data-studio -y
choco install powerbi -y
# choco install sqlsentryplanexplorer -y # download and install from SentryOne
choco install visualstudio2017sql -y
choco install visualstudio2017community -y
choco install visualstudio2019community -y
# choco install github-desktop -y # download and install from GitHub
choco install visualstudio-github -y
# choco install docker-desktop -y # download and install from Docker
# choco install docker-compose -y # download and install from Docker
# choco install docker-cli -y # download and install from Docker
choco install azure-cli -y
# choco install python -y
# choco install terraform -y
# choco install terraform-docs -y
# choco install microsoftazurestorageexplorer -y
choco install pencil -y
choco install powertoys -y
# vscode extensions
$vscodeextensions = @(
    "ms-vscode.powershell",
    "ms-mssql.mssql",
    "ms-mssql.sql-database-projects-vscode",
    "ms-mssql.data-workspace-vscode",
    "ms-azuretools.vscode-docker",
    "ms-vscode-remote.remote-containers",
    "taoklerks.poor-mans-t-sql-formatter-vscode",
    "github.copilot",
    "github.vscode-pull-request-github",
    "eamodio.gitlens",
    "yzhang.markdown-all-in-one",
    "davidanson.vscode-markdownlint",
    "streetsidesoftware.code-spell-checker"
)
[string] $Cmd = "C:\Program Files\Microsoft VS Code\bin\code.cmd"
[string] $Arguments = ""
foreach ($vscodeextension in $vscodeextensions) {
    [string] $Arguments = "--install-extension " + $vscodeextension
    Start-Process -FilePath $Cmd -ArgumentList $Arguments -Wait -NoNewWindow
}
# support
choco install sysinternals -y
choco install cpu-z -y
choco install treesizefree -y
choco install microsoft-windows-terminal -y
choco install etcher -y
# other
choco install myfamilytree -y
choco install myfamilytree-languagepack -y
# --------------------------------------------------
choco upgrade all -y
# --------------------------------------------------
