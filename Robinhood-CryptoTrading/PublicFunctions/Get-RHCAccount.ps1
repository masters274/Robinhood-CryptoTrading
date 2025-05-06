function Get-RHCAccount { 
 
    <#
        .SYNOPSIS
            Retrieves information about a Robinhood Crypto trading account.

        .DESCRIPTION
            This function makes an authenticated request to the Robinhood Crypto API to retrieve
            information about the user's crypto trading account, including balances, buying power,
            and account status.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .EXAMPLE
            Get-RHCAccount

            Retrieves account information using stored credentials.

        .EXAMPLE
            Get-RHCAccount -ApiKey "your-api-key" -PrivateKeySeed "your-private-key-seed"

            Retrieves account information using the specified API key and private key seed.

        .OUTPUTS
            Returns a PSCustomObject containing the account information from the Robinhood Crypto API.

        .NOTES
            This function requires valid Robinhood Crypto API credentials and the BouncyCastle cryptography library.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $false)]
        [string] $BaseUrl = "https://trading.robinhood.com"
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        # Create an RHMessage for the GET request to the crypto account endpoint.
        $msg = [RHMessage]::new($ApiKey, "/api/v1/crypto/trading/accounts/", "GET", $null)
        if (-not $msg.IsValid()) {
            throw "RHMessage is not valid. Please check that ApiKey, Path, and Method are set."
        }

        $msg.Sign($PrivateKeySeed)
        $response = Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
        return $response
    }
 
 };

