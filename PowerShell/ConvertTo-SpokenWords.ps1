Add-Type -AssemblyName System.Speech

function ConvertTo-SpokenWords {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)] 
            [string] $TextToSpeak
        ,
        [Parameter(Position=1, Mandatory=$false)] 
            [string] $ExportWavFilePath
    )
    $Talk = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer

    if (![String]::IsNullOrEmpty($ExportWavFilePath)) { $Talk.SetOutputToWaveFile($ExportWavFilePath) }
    $Talk.SpeakAsync($TextToSpeak) | Out-Null
}
