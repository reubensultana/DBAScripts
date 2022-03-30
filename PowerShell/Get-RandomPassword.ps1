# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-RandomPassword.ps1

function Get-RandomPassword {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)] [int] $OutputLength
    )
    
    # check and default to 12
    if ($null -eq $OutputLength -or $OutputLength -lt 8) { $OutputLength = 12 }

    # arrays of alowed characters
    $UpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $LowerCase = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $Numbers = "0123456789".ToCharArray()
    $Symbols = "!@#$%^&*()-_=+{}[]|\:;<>,.?/".ToCharArray()

    # build a single array of all characters
    $AllowedCharacters = $UpperCase + $LowerCase + $Numbers + $Symbols

    # check the requested length
    # NOTE: max output length for this function (as is) is 72 characters
    [int] $MaxLength = $($AllowedCharacters -join '').Length
    if ($OutputLength -gt $MaxLength) { $OutputLength = $MaxLength }

    # build the password
    [string] $Password = ($AllowedCharacters | Get-Random -Count $OutputLength) -join ''
    
    Return $Password
}
