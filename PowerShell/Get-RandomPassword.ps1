# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-RandomPassword.ps1

function Get-RandomPassword {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)] [int] $OutputLength
        ,
        [Parameter(Position=1, Mandatory=$false)] [bool] $UseUpper = $true
        ,
        [Parameter(Position=2, Mandatory=$false)] [bool] $UseLower = $true
        ,
        [Parameter(Position=3, Mandatory=$false)] [bool] $UseNumbers = $true
        ,
        [Parameter(Position=4, Mandatory=$false)] [bool] $UseSymbols = $true
        ,
        [Parameter(Position=5, Mandatory=$false)] [string] $OverrideSymbols = $null
    )
    
    # check and default to 12
    if ($null -eq $OutputLength -or $OutputLength -lt 8) { $OutputLength = 12 }
    
    # check that at least one category has been selected
    if (($false -eq $UseUpper) -and ($false -eq $UseLower) -and ($false -eq $UseNumbers) -and ($false -eq $UseSymbols)) { 
        Write-Error "You cannot exclude all categories. The best option is to omit values and stick to the defaults"
        Return $null
    }

    # arrays of allowed characters
    if ($true -eq $UseUpper) { $UpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray() } else { $UpperCase = $null }
    if ($true -eq $UseLower) { $LowerCase = "abcdefghijklmnopqrstuvwxyz".ToCharArray() } else { $LowerCase = $null }
    if ($true -eq $UseNumbers) { $Numbers = "0123456789".ToCharArray() } else { $Numbers = $null }
    if ($true -eq $UseSymbols) {
        if (($null -eq $OverrideSymbols) -or ($OverrideSymbols.Length -lt 1)) { $Symbols = "!@#$%^&*()-_=+{}[]|\:;<>,.?/".ToCharArray() }
        else { $Symbols = $OverrideSymbols.ToCharArray() }
    } else { $Symbols = $null }

    # build a single array of all characters
    $AllowedCharacters = $UpperCase + $LowerCase + $Numbers + $Symbols

    # check the requested length
    # NOTE: max output length for this function (as is) is 72 characters
    [int] $MaxLength = $($AllowedCharacters -join '').Length
    if ($OutputLength -gt $MaxLength) { $OutputLength = $MaxLength }

    # build the password
    [string] $Password = ($AllowedCharacters | Get-Random -Count $OutputLength -ErrorAction SilentlyContinue) -join ''
    
    Return $Password
}
