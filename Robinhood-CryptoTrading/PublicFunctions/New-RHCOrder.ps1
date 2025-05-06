function New-RHCOrder { 
 

    <#
        .SYNOPSIS
            Creates a new cryptocurrency order on Robinhood.

        .DESCRIPTION
            This function allows you to place cryptocurrency orders on Robinhood, supporting
            various order types including market orders, limit orders, stop loss orders, and
            stop limit orders. It handles the authentication and request signing process
            automatically.

        .PARAMETER Side
            Required. Specifies the side of the order: "buy" or "sell".

        .PARAMETER Symbol
            Required. The trading pair symbol for the order (e.g., "BTC-USD", "ETH-USD").

        .PARAMETER AssetQuantity
            Required. The quantity of the cryptocurrency asset to buy or sell.

        .PARAMETER QuoteAmount
            Required for limit, stop loss, and stop limit orders. The total amount in the quote currency.

        .PARAMETER TimeInForce
            Required for limit, stop loss, and stop limit orders. Specifies how long the order remains active:
            "gtc" (Good Till Canceled) or "day" (Day Order).

        .PARAMETER LimitPrice
            Required for limit and stop limit orders. The price at which the order should execute.

        .PARAMETER StopPrice
            Required for stop loss and stop limit orders. The price that triggers the order.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER ClientOrderId
            Optional. A unique identifier for the order. If not specified, a new GUID will be generated.

        .PARAMETER BaseUrl
            Optional. The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .EXAMPLE
            New-RHCOrder -Side "buy" -Symbol "BTC-USD" -AssetQuantity "0.001"

            Creates a market order to buy 0.001 Bitcoin.

        .EXAMPLE
            New-RHCOrder -Side "sell" -Symbol "ETH-USD" -AssetQuantity "0.1" -QuoteAmount "300" -TimeInForce "gtc" -LimitPrice "3000"

            Creates a limit order to sell 0.1 Ethereum at a price of $3000, with a total value of $300.

        .EXAMPLE
            New-RHCOrder -Side "buy" -Symbol "BTC-USD" -AssetQuantity "0.001" -QuoteAmount "25" -TimeInForce "day" -StopPrice "25000"

            Creates a stop loss order to buy 0.001 Bitcoin when the price reaches $25,000, with a total value of $25.

        .EXAMPLE
            New-RHCOrder -Side "sell" -Symbol "DOGE-USD" -AssetQuantity "1000" -QuoteAmount "100" -TimeInForce "gtc" -StopPrice "0.09" -LimitPrice "0.1"

            Creates a stop limit order to sell 1000 Dogecoin when the price reaches $0.09, with a limit price of $0.10.

        .OUTPUTS
            Returns a PSCustomObject containing the order information from the Robinhood Crypto API.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("buy", "sell")]
        [string] $Side,

        [Parameter(Mandatory = $true)]
        [string] $Symbol,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Market", "Limit", "StopLoss", "StopLimit")]
        [string] $OrderType,

        [Parameter(Mandatory = $false)]
        [string] $AssetQuantity,

        [Parameter(Mandatory = $false)]
        [string] $QuoteAmount,

        [Parameter(Mandatory = $false)]
        [ValidateSet("gtc", "day")]
        [string] $TimeInForce,

        [Parameter(Mandatory = $false)]
        [string] $LimitPrice,

        [Parameter(Mandatory = $false)]
        [string] $StopPrice,

        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $false)]
        [string] $ClientOrderId,

        [Parameter(Mandatory = $false)]
        [string] $BaseUrl = "https://trading.robinhood.com"
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {
        # Validate parameters based on OrderType
        switch ($OrderType) {
            'Market' {
                if ([string]::IsNullOrEmpty($AssetQuantity)) {
                    throw "AssetQuantity is required for Market orders"
                }
                if ($QuoteAmount) {
                    Write-Warning "QuoteAmount is not supported for Market orders and will be ignored"
                }
            }
            'Limit' {
                if ([string]::IsNullOrEmpty($AssetQuantity)) {
                    throw "AssetQuantity is required for Limit orders"
                }
                if ([string]::IsNullOrEmpty($TimeInForce)) {
                    throw "TimeInForce is required for Limit orders"
                }
                if ([string]::IsNullOrEmpty($LimitPrice)) {
                    throw "LimitPrice is required for Limit orders"
                }
            }
            'StopLoss' {
                if ([string]::IsNullOrEmpty($AssetQuantity)) {
                    throw "AssetQuantity is required for StopLoss orders"
                }
                if ([string]::IsNullOrEmpty($TimeInForce)) {
                    throw "TimeInForce is required for StopLoss orders"
                }
                if ([string]::IsNullOrEmpty($StopPrice)) {
                    throw "StopPrice is required for StopLoss orders"
                }
            }
            'StopLimit' {
                if ([string]::IsNullOrEmpty($AssetQuantity)) {
                    throw "AssetQuantity is required for StopLimit orders"
                }
                if ([string]::IsNullOrEmpty($TimeInForce)) {
                    throw "TimeInForce is required for StopLimit orders"
                }
                if ([string]::IsNullOrEmpty($LimitPrice)) {
                    throw "LimitPrice is required for StopLimit orders"
                }
                if ([string]::IsNullOrEmpty($StopPrice)) {
                    throw "StopPrice is required for StopLimit orders"
                }
            }
        }

        if (-not $ClientOrderId) {
            $ClientOrderId = [guid]::NewGuid().ToString()
        }

        $payload = @{
            client_order_id = $ClientOrderId
            side            = $Side
            symbol          = $Symbol
        }

        switch ($OrderType) {
            'Market' {
                $payload.Add("type", "market")
                $payload.Add("market_order_config", @{ asset_quantity = $AssetQuantity })
            }
            'Limit' {
                $payload.Add("type", "limit")
                $config = @{
                    asset_quantity = $AssetQuantity
                    limit_price    = $LimitPrice
                    time_in_force  = $TimeInForce
                }
                if ($QuoteAmount) {
                    $config.Add("quote_amount", $QuoteAmount)
                }
                $payload.Add("limit_order_config", $config)
            }
            'StopLoss' {
                $payload.Add("type", "stop_loss")
                $config = @{
                    asset_quantity = $AssetQuantity
                    stop_price     = $StopPrice
                    time_in_force  = $TimeInForce
                }
                if ($QuoteAmount) {
                    $config.Add("quote_amount", $QuoteAmount)
                }
                $payload.Add("stop_loss_order_config", $config)
            }
            'StopLimit' {
                $payload.Add("type", "stop_limit")
                $config = @{
                    asset_quantity = $AssetQuantity
                    stop_price     = $StopPrice
                    limit_price    = $LimitPrice
                    time_in_force  = $TimeInForce
                }
                if ($QuoteAmount) {
                    $config.Add("quote_amount", $QuoteAmount)
                }
                $payload.Add("stop_limit_order_config", $config)
            }
        }

        Write-Verbose "Using order type: $OrderType"
        Write-Verbose "Order payload: $($payload | ConvertTo-Json -Compress)"

        $jsonBody = $payload | ConvertTo-Json -Depth 5
        $path = "/api/v1/crypto/trading/orders/"
        $msg = [RHMessage]::new($ApiKey, $path, "POST", $jsonBody)

        if (-not $msg.IsValid()) {
            throw "RHMessage is not valid."
        }

        $msg.Sign($PrivateKeySeed)
        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

