# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-PublicIP.ps1

[string] $ApiUrl = ""

# various options available:
$ApiUrl = "http://ifconfig.me/ip"

$ApiUrl = "https://api.ipify.org"

$ApiUrl = "http://api.seeip.org"

$ApiUrl = "http://ident.me"

$ApiUrl = "https://api.ipify.org"

$ApiUrl = "https://ipv4.getmyip.dev"

$ApiUrl = "https://ipinfo.io" # NOTE: this returns a JSON structure

$ApiUrl = "https://us1.api-bdc.net/data/client-ip" # NOTE: this returns a JSON structure

$ApiUrl = "https://wtfismyip.com/json" # NOTE: this returns a JSON structure

$ApiUrl = "https://myip.wtf/json" # NOTE: this returns a JSON structure


# get the public IP address
$(Invoke-WebRequest -uri $ApiUrl).Content
