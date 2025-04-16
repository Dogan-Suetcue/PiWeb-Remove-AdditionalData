function Resolve-CurrentError
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $LogFilePath,

        [Parameter(Mandatory)]
        [object]
        $CurrentError,

        [Parameter(Mandatory = $false)]
        [string]
        $PartPath
    )

    if (($CurrentError.Exception.GetType().BaseType -eq [System.Net.Http.HttpRequestException]) -and ($null -eq $PartPath))
    {                                     
        Resolve-HttpError $CurrentError.Exception.Response.StatusCode $LogFilePath $uri $PartPath
        Write-Log $LogFilePath 'The programme is hereby terminated'
        Exit 1
    }
    else
    {
        Write-Log $LogFilePath $CurrentError.Exception.Message Error
    }
}

function Get-NextNumberOfDays
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]
        $NumberOfDays,

        [Parameter(Mandatory)]
        [int]
        $RelativeDaysStep,

        [Parameter(Mandatory)]
        [int]
        $RelativeDaysEnd
    )

    if ($NumberOfDays - $RelativeDaysStep -gt $RelativeDaysEnd)
    {
        return $NumberOfDays -= $RelativeDaysStep
    }
    elseif ($NumberOfDays -ne $RelativeDaysEnd)
    {
        return $RelativeDaysEnd
    }
    else 
    {
        return $null
    }
}

function New-CustomObject {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $PartPath,

        [Parameter(Mandatory)]
        [string]
        $FileName,

        [Parameter(Mandatory)]
        [int]
        $FileCount,

        [Parameter(Mandatory)]
        [int]
        $FileSize,

        [Parameter(Mandatory)]
        [string]
        $Entity
    )

    return [PSCustomObject]@{
        PartPath = $PartPath
        FileName = $FileName
        FileCount = $FileCount
        FileSize = $FileSize
        Entity = $Entity
    }
}

function Update-Dictionary
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [hashtable]
        $Dictionary,

        [Parameter(Mandatory)]
        [string]
        $PartPath,

        [Parameter(Mandatory)]
        [string]
        $FileName,

        [Parameter(Mandatory)]
        [int]
        $FileSize,

        [Parameter(Mandatory)]
        [string]
        $Entity
    )

    $hashKey = Get-HashKey(@($partPath, $FileName))

    if (-not $Dictionary.ContainsKey($hashKey))
    {
        $Dictionary.Add($hashKey, (New-CustomObject -PartPath $PartPath -FileName $Filename -FileCount 1 -FileSize $FileSize -Entity $Entity))
    }
    else
    {
        $Dictionary[$hashKey].FileCount += 1
        $Dictionary[$hashKey].FileSize += $FileSize
    }
}

function Write-Summary
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $LogFilePath,

        [Parameter(Mandatory)]
        [bool]
        $DetailedReport,

        [Parameter(Mandatory)]
        [hashtable]
        $Dictionary,

        [Parameter(Mandatory)]
        [int]
        $TotalFileCount,

        [Parameter(Mandatory)]
        [double]
        $TotalFileSize,

        [Parameter(Mandatory)]
        [System.Diagnostics.Stopwatch]
        $Stopwatch
    )

    Write-Log $LogFilePath '###########################'
    Write-Log $LogFilePath 'Summary'
    Write-Log $LogFilePath '###########################'

    Write-Log -LogFilePath $LogFilePath -Message "The deletion process took: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -LogSeverity Info
    
    if ($DetailedReport)
    {
        $groups = $Dictionary.Values | Group-Object -Property PartPath
        $TotalFileSize = 0
        $TotalFileCount = 0
        foreach ($group in $groups)
        {
            $group.Group | 
            Sort-Object -Property FileSize -Descending | 
            Format-Table -Property PartPath, FileName, FileCount, @{Name='FileSize'; Expression={Convert-FileSize -FileSizeInBytes $_.FileSize}}, Entity -AutoSize | 
            Tee-Object -FilePath $LogFilePath -Append
    
            $sumFileSize = ($group.Group | Measure-Object -Property FileSize -Sum).Sum
            $totalFileSize += $sumFileSize
    
            $sumFileCount = ($group.Group | Measure-Object -Property FileCount -Sum).Sum
            $totalFileCount += $sumFileCount

            $message = "A total of $($sumFileCount) additional data with a size of $(Convert-FileSize -FileSizeInBytes $sumFileSize) was deleted for part $($group.Name).)"
            Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Info
        }        
    }

    $message = "A total of $($TotalFileCount) additional data with a total size of $(Convert-FileSize -FileSizeInBytes $TotalFileSize) of data was deleted for all parts"
    Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Info
}

function Show-ProgressBar
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory)]
        [string]
        $Entity,

        [Parameter(Mandatory)]
        [int]
        $CurrentFileCount,

        [Parameter(Mandatory)]
        [int]
        $MaxFileCount
    )

    $percentage = ($CurrentFileCount / $MaxFileCount) * 100
    $params = @{
        Activity = "Delete additional $($Entity) data"
        Status = "$($percentage.ToString('#.##'))% complete"
        PercentComplete = $percentage
    }
    Write-Progress @params
}

function Test-PSVersion
{
    [CmdletBinding()]
    param (
        [version]
        $RequiredVersion = "7.5.1",

        [version]
        $CurrentVersion = $PSVersionTable.PSVersion
    )

    if ($CurrentVersion -lt $RequiredVersion) {
        Write-Host "The PowerShell version is $CurrentVersion. The script requires at least version 7.5.1." -ForegroundColor Red
        Exit 1
    }
}

Export-ModuleMember -Function *