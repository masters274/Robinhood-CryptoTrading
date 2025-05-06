function Get-RHCBestBidAsk { 
 
    <#
        .SYNOPSIS
            Retrieves the best bid and ask quotes for cryptocurrency trading pairs on Robinhood.

        .DESCRIPTION
            This function makes an authenticated request to the Robinhood Crypto API to get the current best bid and ask
            quotes for one or more specified cryptocurrency trading pairs. These are the most competitive buy and sell
            offers currently available on the market.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .PARAMETER Symbol
            One or more cryptocurrency trading pair symbols (case-sensitive) to retrieve quotes for.
            For example: "BTC-USD", "ETH-USD", "DOGE-USD".
            If not specified, returns data for all available trading pairs.

        .EXAMPLE
            Get-RHCBestBidAsk -Symbol "BTC-USD"

            Returns the best bid and ask quotes for Bitcoin in USD.

        .EXAMPLE
            Get-RHCBestBidAsk -Symbol "BTC-USD","ETH-USD"

            Returns the best bid and ask quotes for multiple cryptocurrencies.

        .EXAMPLE
            Get-RHCBestBidAsk

            Returns the best bid and ask quotes for all available trading pairs.

        .OUTPUTS
            Returns a PSCustomObject containing the best bid and ask quote information from the Robinhood Crypto API.

        .NOTES
            This function requires valid Robinhood Crypto API credentials and the BouncyCastle cryptography library.
            The quotes represent the current market state and can change rapidly.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $false)]
        [string] $BaseUrl = "https://trading.robinhood.com",

        [Parameter(Mandatory = $false, HelpMessage = 'Case sensitive. i.e. BTC-USD')]
        [string[]] $Symbol
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        $query = ""

        if ($Symbol) {
            $query = Build-RHCQueryString -Parameters @{ symbol = $Symbol }
        }

        $path = "/api/v1/crypto/marketdata/best_bid_ask/$query"
        $msg = [RHMessage]::new($ApiKey, $path, "GET", $null)

        if (-not $msg.IsValid()) { throw "RHMessage is not valid." }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

