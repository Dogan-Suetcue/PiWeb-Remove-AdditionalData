enum LogSeverity
{
    Info
    Warn
    Error
    Success
}

function Test-BaseURL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $BaseURL
    )

    $regex = '^http(s)?:\/\/\w+:\d{2,4}$'
    if (-not ($BaseURL -match $regex))
    {
        $message = "Invalid base URL: $($BaseURL). Please enter a valid base URL e.g. `"http://locahost:8080`". The programme is hereby terminated."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
        Exit 1
    }
}

function New-LogFile
{
    param
    (
        [string]$LogFilePath
    )

    $logDirectory = Split-Path -Path $LogFilePath -Parent
    if ([String]::IsNullOrWhiteSpace($logDirectory))
    {
        return
    }

    if (-not (Test-Path -Path $logDirectory)) 
    {
        New-Item -ItemType Directory -Path $logDirectory -Force
    }  
}

function New-Base64LoginData
{
    # Ask user for username and password
    $userName = Read-Host -Prompt "Enter your user name."
    $password = Read-Host -Prompt "Enter your password." -MaskInput

    # Combine login data
    $loginData = "$($UserName):$($password)"

    # Encoding login data in Base64
    return [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($loginData))
}

function Write-Log
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory)]
        [string]
        $LogFilePath,

        [Parameter(Mandatory)]
        [string]
        $Message,

        [Parameter(Mandatory = $false)]
        [LogSeverity]
        $LogSeverity = [LogSeverity]::Info
    )

    $timeStamp = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    $logEntry = "$($LogSeverity) - $($timeStamp) - $($Message)"

    Add-Content -Path $LogFilePath -Value $logEntry

    if ($LogSeverity -eq [LogSeverity]::Success)
    {
        Write-Host $logEntry -ForegroundColor Green
    }
    elseif ($LogSeverity -eq [LogSeverity]::Warn)
    {
        Write-Host $logEntry -ForegroundColor Yellow
    }
    elseif (($LogSeverity -eq [LogSeverity]::Error))
    {
        Write-Host $logEntry -ForegroundColor Red
    }
    else 
    {
        Write-Host $logEntry
    }
}

function Get-HashKey() 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]
        $arguments
    )

    $combinedString = $arguments -join ''
    $hash = [System.Security.Cryptography.HashAlgorithm]::Create("SHA256")
    $hashBytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combinedString))
    $hashString = [BitConverter]::ToString($hashBytes) -replace "-", ""
    return $hashString
}

function Convert-FileSize
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [int]
        $FileSizeInBytes
    )

    if ($FileSizeInBytes -ge 1MB) {
        return "{0:N2} MB" -f ($FileSizeInBytes / 1MB)
    } elseif ($FileSizeInBytes -ge 1KB) {
        return "{0:N2} KB" -f ($FileSizeInBytes / 1KB)
    } else {
        return "$FileSizeInBytes Bytes"
    }
}

Export-ModuleMember -Function *