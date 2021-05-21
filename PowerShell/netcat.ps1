param(
    [string] $hostname = "127.0.0.1",
    [int] $port = 3389
     )

# The $hostname value can be either a DNS CName/Alias or an IP Address
try {
    #Write-Host "Connecting to $hostname..."
	$ip = [System.Net.Dns]::GetHostAddresses($hostname) | 
		Select-Object IPAddressToString -expandproperty  IPAddressToString
	if ($ip.GetType().Name -eq "Object[]") {
		# if we have several ip's for a host name we'll simply use the first one
		$ip = $ip[0]
	}
} 
catch {
	Write-Host "Connect failed - Hostname or IP Address $hostname could be incorrect"
	Return $False
}
$t = New-Object Net.Sockets.TcpClient
# Use Try\Catch to remove exception info from the console if we can't connect
try {$t.Connect($ip,$port)} catch {}

if($t.Connected) {
	$t.Close()
    if ($hostname -eq $ip) {
        Write-Host "Successfully connected to $ip on port $port"
        }
    else {
        Write-Host "Successfully connected to $hostname ($ip) on port $port"
    }
	Return $True
}
else {
    Write-Host "Connect failed - Could not open connection to $hostname on port $port"
	Return $False
}
