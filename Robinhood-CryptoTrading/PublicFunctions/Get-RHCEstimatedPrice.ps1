function Get-RHCEstimatedPrice { 
 
    <#
        .SYNOPSIS
            Retrieves estimated price information for a cryptocurrency trading pair on Robinhood.

        .DESCRIPTION
            This function makes an authenticated request to the Robinhood Crypto API to get estimated price
            information for a specified cryptocurrency trading pair, side (bid/ask/both), and quantity.
            This can be used to estimate the execution price of an order before placing it.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER Symbol
            The cryptocurrency trading pair symbol (case-sensitive) to retrieve price estimation for,
            e.g., "BTC-USD", "ETH-USD", "DOGE-USD".

        .PARAMETER Side
            The side of the order for which to retrieve price estimation.
            Valid values: "bid" (buy), "ask" (sell), or "both".

        .PARAMETER Quantity
            The quantity of the cryptocurrency for which to estimate the price.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .EXAMPLE
            Get-RHCEstimatedPrice -Symbol "BTC-USD" -Side "bid" -Quantity "0.001"

            Returns the estimated price for buying 0.001 Bitcoin.

        .EXAMPLE
            Get-RHCEstimatedPrice -Symbol "ETH-USD" -Side "ask" -Quantity "0.1"

            Returns the estimated price for selling 0.1 Ethereum.

        .EXAMPLE
            Get-RHCEstimatedPrice -Symbol "DOGE-USD" -Side "both" -Quantity "100"

            Returns the estimated prices for both buying and selling 100 Dogecoin.

        .OUTPUTS
            Returns a PSCustomObject containing the estimated price information from the Robinhood Crypto API.

        .NOTES
            This function requires valid Robinhood Crypto API credentials and the BouncyCastle cryptography library.
            The estimated prices are based on current market conditions and may differ from actual execution prices.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $true)]
        [string] $Symbol,

        [Parameter(Mandatory = $true)]
        [ValidateSet("bid", "ask", "both")]
        [string] $Side,

        [Parameter(Mandatory = $true)]
        [string] $Quantity,

        [Parameter(Mandatory = $false)]
        [string] $BaseUrl = "https://trading.robinhood.com"
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        $query = Build-RHCQueryString -Parameters @{ symbol = $Symbol; side = $Side; quantity = $Quantity }
        $path = "/api/v1/crypto/marketdata/estimated_price/$query"
        $msg = [RHMessage]::new($ApiKey, $path, "GET", $null)

        if (-not $msg.IsValid()) { throw "RHMessage is not valid." }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

