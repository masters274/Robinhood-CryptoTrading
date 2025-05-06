function Get-RHCTradingPairs { 
 
    <#
        .SYNOPSIS
            Retrieves information about available cryptocurrency trading pairs on Robinhood.

        .DESCRIPTION
            This function makes an authenticated request to the Robinhood Crypto API to retrieve
            information about available cryptocurrency trading pairs, including trading status,
            minimum order sizes, and other relevant details.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .PARAMETER Symbols
            Optional. One or more trading pair symbols (e.g., "BTC-USD", "ETH-USD") to filter the results.
            If not specified, returns data for all available trading pairs.

        .EXAMPLE
            Get-RHCTradingPairs

            Returns information about all available cryptocurrency trading pairs.

        .EXAMPLE
            Get-RHCTradingPairs -Symbols "BTC-USD"

            Returns information about only the Bitcoin-USD trading pair.

        .EXAMPLE
            Get-RHCTradingPairs -Symbols "BTC-USD","ETH-USD"

            Returns information about the Bitcoin-USD and Ethereum-USD trading pairs.

        .OUTPUTS
            Returns a PSCustomObject containing trading pair information from the Robinhood Crypto API.

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
        [string[]] $Symbols
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        $query = ""

        if ($Symbols) {
            $query = Build-RHCQueryString -Parameters @{ symbol = $Symbols }
        }

        $path = "/api/v1/crypto/trading/trading_pairs/$query"
        $msg = [RHMessage]::new($ApiKey, $path, "GET", $null)

        if (-not $msg.IsValid()) { throw "RHMessage is not valid." }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

