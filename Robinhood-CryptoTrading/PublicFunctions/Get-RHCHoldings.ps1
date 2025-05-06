function Get-RHCHoldings { 
 
    <#
        .SYNOPSIS
            Retrieves cryptocurrency holdings information from a Robinhood account.

        .DESCRIPTION
            This function makes an authenticated request to the Robinhood Crypto API to retrieve
            information about the user's current cryptocurrency holdings, including quantities,
            cost basis, and current values.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .PARAMETER AssetCodes
            Optional. One or more cryptocurrency asset codes (e.g., "BTC", "ETH") to filter the results.
            If not specified, returns data for all holdings.

        .EXAMPLE
            Get-RHCHoldings

            Returns information about all cryptocurrency holdings in the user's account.

        .EXAMPLE
            Get-RHCHoldings -AssetCodes "BTC"

            Returns information about only Bitcoin holdings in the user's account.

        .EXAMPLE
            Get-RHCHoldings -AssetCodes "BTC","ETH"

            Returns information about Bitcoin and Ethereum holdings in the user's account.

        .OUTPUTS
            Returns a PSCustomObject containing the holdings information from the Robinhood Crypto API.

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
        [string] $BaseUrl = "https://trading.robinhood.com",

        [Parameter(Mandatory = $false)]
        [string[]] $AssetCodes
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        $query = ""
        if ($AssetCodes) {
            $query = Build-RHCQueryString -Parameters @{ asset_code = $AssetCodes }
        }

        $path = "/api/v1/crypto/trading/holdings/$query"
        $msg = [RHMessage]::new($ApiKey, $path, "GET", $null)

        if (-not $msg.IsValid()) { throw "RHMessage is not valid." }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

