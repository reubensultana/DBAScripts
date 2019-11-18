# --------------------------------------------------
# Using Powershell - administrator mode:
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# --------------------------------------------------
# https://chocolatey.org/
# base
choco install chocolatey -y
# security
choco install malwarebytes -y
choco install keepass -y
# basics
choco install javaruntime -y
choco install googlechrome -y
choco install googledrive -y
choco install 7zip.install -y
choco install notepadplusplus.install -y
choco install foxitreader -y
choco install wps-office-free -y
# social
choco install skype -y
choco install zoom -y
# media
choco install paint.net -y
choco install audacity -y
choco install k-litecodecpackfull -y
choco install spotify -y
# dev
choco install mremoteng -y
choco install sql-server-management-studio -y
choco install vscode -y
choco install azure-data-studio -y
choco install vscode-powershell -y
choco install powershell-core -y
choco install vscode-settingssync -y
choco install powerbi -y
choco install sqlsentryplanexplorer -y
choco install visualstudio2017sql -y
choco install visualstudio2017community -y
choco install visualstudio2019community -y
choco install github-desktop -y
choco install visualstudio-github -y
choco install docker-desktop -y
choco install docker-compose -y
choco install docker-cli -y
choco install pencil -y
# support
choco install sysinternals -y
choco install cpu-z -y
choco install treesizefree -y
choco install microsoft-windows-terminal -y
# --------------------------------------------------
choco upgrade all -y
# --------------------------------------------------
