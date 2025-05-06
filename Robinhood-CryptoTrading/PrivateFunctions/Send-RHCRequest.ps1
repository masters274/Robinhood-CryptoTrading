function Send-RHCRequest { 
 
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [RHMessage] $RHMessage,

        [Parameter(Mandatory = $true)]
        [string] $BaseUrl
    )

    if (-not $RHMessage.IsValid()) {
        throw "RHMessage is not valid. Please check that ApiKey, Path, and Method (and Body for non-GET) are set."
    }

    if ([string]::IsNullOrWhiteSpace($RHMessage.Signature)) {
        throw "RHMessage is not signed. Please call the Sign() method before sending the request."
    }

    # Build the full URI.
    $uri = $BaseUrl.TrimEnd("/") + $RHMessage.Path
    $headers = $RHMessage.GetHeaders()

    # Build a common parameter hash table for splatting.
    $invokeParams = @{
        Uri         = $uri
        Method      = $RHMessage.Method
        Headers     = $headers
        ErrorAction = 'Stop'
    }

    # If the request method is not GET, add the Body parameter.
    if ($RHMessage.Method.ToUpper() -ne "GET") {
        $invokeParams.Add("Body", $RHMessage.Body)
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        return $response
    }
    catch {
        throw "Error sending RH request: $_"
    }
 
 };

