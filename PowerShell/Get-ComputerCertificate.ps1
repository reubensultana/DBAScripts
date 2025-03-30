# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-ComputerCertificate.ps1

# export the computer certificate
[string] $CertificateName = "Remote Desktop Authentication*"

$HostCert = Get-ChildItem -Path Cert:\LocalMachine\My\ | `
    Where-Object -Property Subject -Like -Value "*$($env:COMPUTERNAME)*" | `
    Where-Object -Property EnhancedKeyUsageList -CLike -Value $CertificateName

Export-Certificate -FilePath "$($env:USERPROFILE)\Documents\$($env:COMPUTERNAME).cer" -Cert $HostCert -Type CERT -Verbose
