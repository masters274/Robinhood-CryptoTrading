function Stop-RHCOrder { 
 
    <#
        .SYNOPSIS
            Cancels an existing cryptocurrency order on Robinhood.

        .DESCRIPTION
            This function sends a request to cancel an active cryptocurrency order on the Robinhood platform.
            It handles the authentication and request signing process automatically.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER OrderId
            The unique identifier of the order to cancel. This is required.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .EXAMPLE
            Stop-RHCOrder -OrderId "12345678-abcd-1234-efgh-123456789abc"

            Cancels the specified order using stored credentials.

        .EXAMPLE
            Stop-RHCOrder -OrderId "12345678-abcd-1234-efgh-123456789abc" -ApiKey "your-api-key" -PrivateKeySeed "your-private-key-seed"

            Cancels the specified order using the provided API key and private key seed.

        .OUTPUTS
            Returns a PSCustomObject containing the response from the Robinhood Crypto API,
            which typically includes status information about the cancellation request.

        .NOTES
            This function can only cancel orders that are still active (e.g., pending or open).
            Orders that have already been executed cannot be canceled.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $true)]
        [string] $OrderId,

        [Parameter(Mandatory = $false)]
        [string] $BaseUrl = "https://trading.robinhood.com"
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        $path = "/api/v1/crypto/trading/orders/$OrderId/cancel/"
        $msg = [RHMessage]::new($ApiKey, $path, "POST", $null)

        if (-not $msg.IsValid()) { throw "RHMessage is not valid." }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

