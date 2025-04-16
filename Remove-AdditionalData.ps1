enum HttpMethod
{
    Get
    Delete
}

function Resolve-CurrentError
{
    [CmdletBinding()]
    param
    (
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

function Remove-AdditionalData
{
        <#
    .SYNOPSIS
    Remove additional data from the PiWeb database.

    .PARAMETER BaseURL
    The URL of the database to be queried. Default value is 'http://localhost:8080'.

    .PARAMETER Entity
    A list of entities to be queried. Possible values are: 'part', 'characteristic', 'measurement', 'value'.
    If measurement and value additional data are to be deleted, the value should be @('measurement', 'value'). Default value is 'value'.

    .PARAMETER Exclude
    A list of file extensions to filter out from deletion. Only files with extensions not included in this list will be deleted.
    If specific files should not be deleted, the value should be @('png', 'meshmodel'). Default value is @().

    .PARAMETER RelativeDaysStart
    The start point of the period to check, in days from today. 
    A value of 365 corresponds to one year ago. Default value is 365.

    .PARAMETER RelativeDaysEnd
    The end point of the period to check, in days from today. 
    A value of 14 corresponds to two weeks ago. Default value is 14.

    .PARAMETER RelativeDaysStep
    The number of days to group together. 
    Smaller steps should be used if there are many measurements per day. Default value is 30.

    .PARAMETER DetailedReport
    If specified, a detailed report will be generated including part paths and file sizes.

    .PARAMETER LogFilePath
    The path to the log file where the results should be saved. 
    Default value is '.\PiWebAdditionalDataDeletionLog.txt'.

    .EXAMPLE
    Remove-AdditionalData -BaseURL 'http://hostname:8080' -Entity @('measurement', 'value') -FileExtensionFilter @('png', 'jpg') -RelativeDaysStart 60 -RelativeDaysEnd 30 -RelativeDaysStep 10 -LogFilePath 'C:\Logs\MyLog.txt' -DetailedReport
    Initializes the parameters with custom values and generates a detailed report.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, HelpMessage = 'Please provide a base URL.')]
        [ValidatePattern('http(s)?:\/\/\w+:\d{2,4}')]
        [string]
        $BaseURL,

        [Parameter(Mandatory, HelpMessage = 'Please select the entity you want to delete.')]
        [ValidateSet('part', 'characteristic', 'measurement', 'value')]
        [string[]]
        $Entity,

        [Parameter(Mandatory = $false)]
        [string[]]
        $Exclude,

        [Parameter(Mandatory)]
        [ValidateRange("Positive")]
        [int]
        $RelativeDaysStart,

        [Parameter(Mandatory)]
        [ValidateRange("Positive")]
        [int]
        $RelativeDaysEnd,

        [Parameter(Mandatory)]
        [ValidateRange("Positive")]
        [int]
        $RelativeDaysStep,

        [switch]$DetailedReport,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string]
        $LogFilePath
    )

    # Import Modules
    Import-Module -Name @('.\Modules\Common.psm1', '.\Modules\PiWebHelper.psm1')

    # Create the log directory if it does not exist
    New-LogFile -LogFilePath $LogFilePath

    # URI validation
    Test-BaseURL -BaseURL $BaseURL
    
    # Test if PiWeb Server service is running
    Test-PiWebServerConnection -BaseURL $BaseURL -LogFilePath $LogFilePath

    # Test if authentication is enabled
    $authInfo = Test-Authentication -BaseURL $BaseURL -LogFilePath $LogFilePath
    $basicAuthenticationEnabled = $authInfo.BasicAuthenticationEnabled
    $credential = $authInfo.Credential

    # Initialize variables
    $totalFileCount = 0
    $totalFileSize = 0.0
    $currentFileCount = 0 
    $maxFileCount = 0
    $numberOfDays = $RelativeDaysStart
    $summaryReport = @{}
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Loop through the date range until reaching the end point
    while ($numberOfDays -ge $RelativeDaysEnd)
    {
        $relativeDays = "-$($numberOfDays)d"
        $message = "Trying to delete additional data older than $($numberOfDays) days."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Info

        foreach ($currentEntity in $Entity)
        {
            try 
            {
                if ($Exclude.Count -gt 0)
                {
                    $fileNameFilter = Get-FileNameFilter -Exlude $Exclude
                    $url = [System.Uri]::new("$($BaseURL)/rawDataServiceRest/rawDataInformation/$($currentEntity)?filter=LastModified le '$($relativeDays)'$($fileNameFilter)")
                }
                else
                {
                    $url = [System.Uri]::new("$($BaseURL)/rawDataServiceRest/rawDataInformation/$($currentEntity)?filter=LastModified le '$($relativeDays)'")
                }

                # Retrieve the additional data for the specified time
                $params = @{
                    BasicAuthenticationEnabled = $basicAuthenticationEnabled
                    Url = $url
                    Credential = $credential
                    HttpMethod = [HttpMethod]::Get
                }
                $rawDataObjects = Invoke-PiWeApiRequest @params

                # Reset variable
                $currentFileCount = 0
                $maxFileCount = $rawDataObjects.Length

                Write-Log -LogFilePath $LogFilePath -Message "`"$($maxFileCount)`" additional data found for the entity `"$($currentEntity)`"." -LogSeverity Info

                # Additional data available?
                if ($maxFileCount -gt 0) 
                {
                    # Delete all additional data
                    foreach ($rawDataObject in $rawDataObjects) 
                    {                                                
                        # Execute the DELETE request
                        $uuid = $rawDataObject.target.uuid
                        $key = $rawDataObject.key
                        $url = [System.Uri]::new("$($BaseURL)/rawDataServiceRest/rawData/$($currentEntity)/$($uuid)/$($key)")
                        try 
                        {
                            $params = @{
                                BasicAuthenticationEnabled = $basicAuthenticationEnabled
                                Url = $url
                                Credential = $credential
                                HttpMethod = [HttpMethod]::Delete
                            }
                            Invoke-PiWeApiRequest @params | Out-Null

                            $currentFileCount += 1
                            Show-ProgressBar -Entity $currentEntity -CurrentFileCount $currentFileCount -MaxFileCount $maxFileCount

                            if ($DetailedReport)
                            {
                                $params = @{
                                    BasicAuthenticationEnabled = $basicAuthenticationEnabled
                                    Credential = $credential
                                    BaseUrl = $BaseURL
                                    CurrentEntity = $currentEntity
                                    RawDataObject = $rawDataObject
                                }
                                $partPath = Get-PartPath @params

                                $params = @{
                                    Dictionary = $summaryReport
                                    PartPath = $partPath
                                    FileName = $rawDataObject.fileName
                                    FileSize = $rawDataObject.size
                                    Entity = $currentEntity
                                }
                                Update-Dictionary @params
                            }
                            else
                            {
                                $totalFileCount += 1
                                $totalFileSize += $rawDataObject.size
                            }
                        }
                        catch 
                        {
                            $params = @{
                                BasicAuthenticationEnabled = $basicAuthenticationEnabled
                                Credential = $credential
                                BaseUrl = $BaseURL
                                CurrentEntity = $currentEntity
                                RawDataObject = $rawDataObject
                            }
                            $partPath = Get-PartPath @params

                            Resolve-CurrentError -CurrentError $_ -PartPath $partPath
                        }              
                    }
                }
            } 
            catch
            {
                Resolve-CurrentError -CurrentError $_ -PartPath $null
            }
        }

        # Get numberOfDays for the next iteration
        $numberOfDays = Get-NextNumberOfDays -NumberOfDays $numberOfDays -RelativeDaysStep $RelativeDaysStep -RelativeDaysEnd $RelativeDaysEnd
        if ($null -eq $numberOfDays)
        {
            break
        }
    }
    
    $stopwatch.Stop()

    $params = @{
        DetailedReport = $DetailedReport
        Dictionary = $summaryReport
        TotalFileCount = $totalFileCount
        TotalFileSize = $totalFileSize
        Stopwatch = $stopwatch
    }
    Write-Summary @params
}

$userInput = Read-Host -Prompt 'Please type (y)es to run the script with the default parameters, or any other key to define the parameters yourself.'
if ($userInput -eq 'y' -or $userInput -eq 'yes')
{
    $params = @{
        BaseUrl = 'http://localhost:8080'
        Entity = @('value')
        Exclude = @()
        RelativeDaysStart = 365
        RelativeDaysEnd = 14
        RelativeDaysStep = 30
        DetailedReport = $false
        LogFilePath = '.\PiWebAdditionalDataDeletionLog.txt'
    }
    Remove-AdditionalData @params
}
else 
{
    Remove-AdditionalData   
}