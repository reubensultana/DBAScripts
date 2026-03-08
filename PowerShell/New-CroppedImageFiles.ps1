function New-CroppedImageFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $FileFilter
        ,[Parameter(Mandatory=$false)] [string] $FileDirectory
        ,[Parameter(Mandatory=$false)] [int] $Top
        ,[Parameter(Mandatory=$false)] [int] $Bottom
        ,[Parameter(Mandatory=$false)] [int] $Left
        ,[Parameter(Mandatory=$false)] [int] $Right
    )
    
    # check if source directory was defined
    if ($null -eq $FileDirectory) {
        $FileDirectory = $pwd
        Write-Warning "Source directory not defined; the current directory ($($FileDirectory)) will be used as default source."
    }
    # check if the values have been defined
    if ($null -eq $Top)     { $Top = 0 }
    if ($null -eq $Bottom)  { $Bottom = 0 }
    if ($null -eq $Left)    { $Left = 0 }
    if ($null -eq $Right)   { $Right = 0 }
    # check if directory exists
    if ($false -eq $(Test-Path -Path $FileDirectory -PathType Container)) {
        Write-Error "Source directory does not exist"
        return
    }
    # check if any files of the specified type exist
    if ($false -eq $(Test-Path -Path "$($FileDirectory)\*.png" -PathType Leaf)) {
        Write-Error "There are no files of the specified type in the source directory"
        return
    }
    if (0 -ge ($Top + $Bottom + $Left + $Right)) {
        Write-Error "All values are zero. Nothing to do"
        return
    }

    [string] $BackupFileNameTemplate = "backup_{0}.zip"
    # get the list of files
    $ChildItem = Get-ChildItem -Path $FileDirectory -Filter $FileFilter -Exclude ($BackupFileNameTemplate -f "*")

    # backup the current version of the identified files
    $ChildItem | Compress-Archive -DestinationPath ("$($FileDirectory)\$($BackupFileNameTemplate)" -f $(Get-Date -Format "yyyyMMddHHmmss"))

    $ChildItem | Sort-Object -Property Name | `
        ForEach-Object { 
            [string] $CurrentFile = "$($_.FullName)"
            Write-Output "Resizing $($CurrentFile)"

            # https://learn.microsoft.com/en-us/previous-versions/windows/desktop/wiaaut/-wiaaut-imagefile
            $WiaObject = New-Object -ComObject WIA.ImageFile
            $WiaObject.LoadFile($CurrentFile)

            # https://learn.microsoft.com/en-us/previous-versions/windows/desktop/wiaaut/-wiaaut-imageprocess
            $WipObject = New-Object -ComObject WIA.ImageProcess
            
            $CropAction = $WipObject.FilterInfos.Item("Crop").FilterId # Crops the image by the specified Left, Top, Right, and Bottom margins.
            $WipObject.Filters.Add($CropAction)
            $WipObject.Filters[1].Properties("Top")     = $Top  # Set the Top property to the top margin (in pixels)
            $WipObject.Filters[2].Properties("Bottom")  = $Bottom  # Set the Bottom property to the bottom margin (in pixels)
            $WipObject.Filters[3].Properties("Left")    = $Left  # Set the Left property to the left margin (in pixels)
            $WipObject.Filters[4].Properties("Right")   = $Right  # Set the Right property to the right margin (in pixels)

            # apply filters and/or other properties
            $WipObject.Apply($WiaObject)
            # create the new image (in memory)
            $NewImg = $WipObject.Apply($WiaObject)
            # delete the existing file
            Remove-Item -Path $CurrentFile -Force -ErrorAction SilentlyContinue
            # write the new cropped image file to disk
            $NewImg.SaveFile($CurrentFile) | Out-Null
        }
}

# crop 60 pixels from the bottom
New-CroppedImageFiles -FileFilter "*.png" -FileDirectory "C:\Users\Public\Pictures" -Bottom 60
