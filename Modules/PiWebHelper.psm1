enum AuthenticationType 
{
    Basic # PiWeb SBS / Essential supports only Basic authentication
}

enum Entity
{
    Part
    Characteristic
    Measurement
    Value
}

enum HttpMethod
{
    Get
    Delete
}

function Get-SupportedAuthenticationType 
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory)]
        [string]
        $BaseUrl
    )


    $url = "$($BaseUrl)/.Well-Known/serverConfiguration"
    $serverConfiguration = Invoke-RestMethod -Method Get -Uri $url

    return $serverConfiguration.authentication_types_supported    
}

function Resolve-HttpError
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory)]
        [System.Net.HttpStatusCode]
        $StatusCode,

        [Parameter(Mandatory)]
        [string]
        $LogFilePath,

        [Parameter(Mandatory)]
        [System.Uri]
        $Url,

        [Parameter(Mandatory)]
        [string]$PartPath
    )

    if ($StatusCode -eq [System.Net.HttpStatusCode]::Unauthorized)
    {
        $message = "The request was invalid (HTTP 401). You are not authorized to access the part: $($PartPath). Please contact your PiWeb administrator."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
    }
    elseif ($StatusCode -eq [System.Net.HttpStatusCode]::BadRequest)
    {
        $message = "The request was invalid (HTTP 400). Please check the query string: `"$($Url.Query)`" and try again."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
    }
    elseif ($StatusCode -eq [System.Net.HttpStatusCode]::NotFound)
    {
        $message = "The requested resource was not found (HTTP 404). Please check the URL: `"$($Url.Authority)$($Url.AbsolutePath)`" and try again."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
    }
    elseif ($StatusCode -eq [System.Net.HttpStatusCode]::Forbidden)
    {
        $message = "Access denied (HTTP 403). You are not authorized to delete additional data for the part: $($PartPath). Please contact your PiWeb administrator."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
    }
    else
    {
        $message = "An error has occurred: $($_.Exception.Message)"
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
    }
}

function Invoke-PiWeApiRequest
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [bool]
        $BasicAuthenticationEnabled,

        [Parameter(Mandatory)]
        [System.Uri]
        $Url,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory)]
        [HttpMethod]
        $HttpMethod
    )

    try 
    {
        if ($BasicAuthenticationEnabled)
        {
            return Invoke-RestMethod -Uri $Url -AllowUnencryptedAuthentication -Credential $Credential -Authentication Basic -Method $HttpMethod.ToString()
        }

        return Invoke-RestMethod -Uri $Url -Method $HttpMethod.ToString()
    }
    catch 
    {
        throw
    }
}

function Select-PartPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $structure = $Path.Split(':')[0]
    if ($structure -eq 'P')
    {
        return $Path.Split(':')[1]
    }

    $pathSegments = $Path.Split(':')[1].Split('/')
    $lastIndex = $structure.LastIndexOf('P')
    return @('', (($pathSegments | Where-Object { $_ -ne '' })[0..$lastIndex]), '') | Join-String -Separator '/'
}

function Get-PartPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [bool]$BasicAuthenticationEnabled,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory)]
        [string]
        $BaseUrl,

        [Parameter(Mandatory)]
        [string]
        $Entity,

        [Parameter(Mandatory)]
        [pscustomobject]
        $RawDataObject
    )

    if ($Entity -eq [Entity]::Characteristic)
    {
        $uuid = $RawDataObject.target.uuid
        $url = [System.Uri]::new("$($BaseUrl)/dataServiceRest/characteristics/$($uuid)")
        $characteristic = Invoke-PiWeApiRequest $BasicAuthenticationEnabled $url $Credential Get
        return Select-PartPath $characteristic.path
    }
    else
    {
        if ($Entity -eq [Entity]::Value)
        {
            $uuid = $RawDataObject.target.uuid.Split("|") | Select-Object -First 1
        }
        else
        {
            $uuid = $RawDataObject.target.uuid
        }
        
        $url = [System.Uri]::new("$($BaseUrl)/dataServiceRest/measurements/$($uuid)")
        $measurement = Invoke-PiWeApiRequest $BasicAuthenticationEnabled $url $Credential Get

        $partUuid = $measurement.partUuid
        $url = [System.Uri]::new("$($BaseUrl)/dataServiceRest/parts/$($partUuid)")
        $part = Invoke-PiWeApiRequest $BasicAuthenticationEnabled $url $Credential Get
        return Select-PartPath $part.path
    }
}

function Get-FileNameFilter
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]
        $Exlude
    )

    $fileNameFilter = ''
    foreach ($extension in $Exlude)
    {
        $fileNameFilter += " and not Filename like '*$($extension)'"
    }

    return $fileNameFilter
}

function Test-PiWebServerConnection
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $BaseURL,

        
        [Parameter(Mandatory)]
        [string]
        $LogFilePath
    )

    $url = [System.Uri]::new($BaseURL)
    $result = Test-NetConnection -ComputerName $url.Host -Port $url.Port
    if ($result.TcpTestSucceeded -eq $false)
    {        
        if ($result.PingSucceeded -eq $false) 
        {
            $message = "Additional information: Ping to the target device '$($url.Host)' has failed."
            Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error

            $message = 'Possible causes: No network connection, firewall blocking pings, target offline, DNS issues, subnet conflicts, hardware failures, overload.'
            Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
        } 
        else 
        {
            $message = "Ping to the target device '$($url.Host)' is successful, but the PiWeb Server service on port '$($url.Port)' is not reachable."
            Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error

            $message = 'Possible causes: Firewall blocking the port, PiWeb Server service not started, network issues.'
            Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Error
        }

        $message = 'Please solve the problems and restart the script.'
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Info
        Exit 1
    }
}

function Test-Authentication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $BaseURL,

        [Parameter(Mandatory)]
        [string]
        $LogFilePath
    )

    # Initialise the variable for authentication
    $basicAuthenticationEnabled = $false
    $credential = $null

    # Check the supported authentication types
    $authenticationTypes = Get-SupportedAuthenticationType -BaseUrl $BaseURL
    if ($authenticationTypes -contains [AuthenticationType]::Basic) {
        $message = "Basis authentication is enabled. Please type in your credentials."
        Write-Log -LogFilePath $LogFilePath -Message $message -LogSeverity Info
        $basicAuthenticationEnabled = $true
        $credential = Get-Credential
    }

    return @{ 
        BasicAuthenticationEnabled = $basicAuthenticationEnabled
        Credential = $credential 
    }    
}

Export-ModuleMember -Function *