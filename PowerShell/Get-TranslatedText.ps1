# Source: https://github.com/reubensultana/DBAScripts/blob/master/PowerShell/Get-TranslatedText.ps1

Set-Location -Path $([System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition))

if ($false -eq $(Test-Path -Path LanguageList.csv)) { throw "The file 'LanguageList.csv' cannot be found." }

# translate text using Google Translate
Class Languages : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        $Global:LanguageList = Import-CSV -Path LanguageList.csv  # convert to read "https://ssl.gstatic.com/inputtools/js/ln/17/en.js" instead?
        return ($Global:LanguageList).Language
    }
}

function Get-TranslatedText {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)] 
            [string] $OriginalText
        ,
        [Parameter(Position=1, Mandatory=$true)] 
            [ValidateSet([Languages], ErrorMessage="Value '{0}' is invalid.")] 
            [string] $TargetLanguage
        ,
        [Parameter(Position=2, Mandatory=$false)]
            [ValidateSet([Languages], ErrorMessage="Value '{0}' is invalid.")] 
            [string] $SourceLanguage
    )
    $OutputEncoding = [System.Text.Encoding]::UTF8

    [string] $TargetLanguageCode = $($LanguageList | Where-Object -Property Language -Match $TargetLanguage).LanguageCode
    [string] $SourceLanguageCode
    if (![String]::IsNullOrEmpty($SourceLanguage)) { 
        $SourceLanguageCode = $($LanguageList | Where-Object -Property Language -Match $SourceLanguage).LanguageCode
    } else { 
        $SourceLanguageCode = "auto" }
    $Uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=$($SourceLanguageCode)&tl=$($TargetLanguageCode)&dt=t&q=$($OriginalText)"
    $Response = Invoke-RestMethod -Uri $Uri -Method Get
    [string] $TranslatedText = $Response[0].SyncRoot | ForEach-Object { $_[0] }
    Return $TranslatedText
}
