function Get-RHCCostBasisSummary { 
 

    <#
        .SYNOPSIS
            Calculates the cost basis for all current crypto holdings.

        .DESCRIPTION
            Retrieves holdings and order history to calculate total cost basis,
            quantity, and average cost per unit for each asset.

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER AssetCodes
            Optional. One or more cryptocurrency asset codes (e.g., "BTC", "ETH") to filter the results.
            If not specified, returns cost basis for all holdings.

        .EXAMPLE
            Get-RHCCostBasisSummary

            Returns cost basis for all cryptocurrency holdings.

        .EXAMPLE
            Get-RHCCostBasisSummary -AssetCodes "BTC"

            Returns cost basis for only Bitcoin holdings.

        .EXAMPLE
            Get-RHCCostBasisSummary -AssetCodes "BTC","ETH"

            Returns cost basis for Bitcoin and Ethereum holdings.

        .NOTES
            When dealing with averages, the result may not be exact. Price change fluxuations over time could also cause inaccuracies.
            This is a best effort calculation based on the order history and current holdings, not transfers in/out.

            Also note that free or transferred crypto assets will show $0, as there is no order history to calculate from.
    #>

    [CmdletBinding()]

    Param (

        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $false)]
        [string[]] $AssetCodes
    )

    Begin {

        Initialize-RHCRequirements | Out-Null

        $authParams = @{
            ApiKey         = $ApiKey
            PrivateKeySeed = $PrivateKeySeed
        }
    }

    Process {

        $holdingsParams = $authParams.Clone()

        if ($AssetCodes) {
            $holdingsParams.Add("AssetCodes", $AssetCodes)
        }

        $holdings = Get-RHCHoldings @holdingsParams

        if (-not $holdings -or -not $holdings.results) {
            Write-Warning "No holdings found."
            return $null
        }

        $results = @()

        foreach ($holding in $holdings.results) {

            $buyOrders = Get-RHCOrder @authParams -QueryParameters @{
                side   = "buy"
                state  = "filled"
                symbol = "$($holding.asset_code)-USD"
            }
            $buyLots = @()
            if ($buyOrders -and $buyOrders.results) {
                foreach ($order in ($buyOrders.results | Sort-Object created_at)) {
                    foreach ($exec in $order.executions) {
                        $buyLots += [PSCustomObject]@{
                            Quantity = [decimal]$exec.quantity
                            Cost     = [decimal]$exec.effective_price * [decimal]$exec.quantity
                        }
                    }
                }
            }


            $sellOrders = Get-RHCOrder @authParams -QueryParameters @{
                side   = "sell"
                state  = "filled"
                symbol = "$($holding.asset_code)-USD"
            }
            $sellExecs = @()
            if ($sellOrders -and $sellOrders.results) {
                foreach ($order in ($sellOrders.results | Sort-Object created_at)) {
                    foreach ($exec in $order.executions) {
                        $sellExecs += [PSCustomObject]@{
                            Quantity = [decimal]$exec.quantity
                        }
                    }
                }
            }

            # FIFO matters here
            foreach ($sell in $sellExecs) {
                $qtyToRemove = $sell.Quantity
                $newBuyLots = @()
                foreach ($lot in $buyLots) {

                    if ($qtyToRemove -le 0) {
                        $newBuyLots += $lot
                        continue
                    }

                    if ($lot.Quantity -le $qtyToRemove) {

                        $qtyToRemove -= $lot.Quantity
                    }
                    else {

                        $remainingQty = $lot.Quantity - $qtyToRemove
                        $remainingCost = $lot.Cost * ($remainingQty / $lot.Quantity)
                        $newBuyLots += [PSCustomObject]@{
                            Quantity = $remainingQty
                            Cost     = $remainingCost
                        }

                        $qtyToRemove = 0
                    }
                }

                $buyLots = $newBuyLots
            }

            $totalQuantity = ($buyLots | Measure-Object Quantity -Sum).Sum
            $totalCost = ($buyLots | Measure-Object Cost -Sum).Sum

            $avgCost = 0

            if ($totalQuantity -gt 0) {
                $avgCost = $totalCost / $totalQuantity
            }

            $results += [PSCustomObject]@{
                AssetCode          = $holding.asset_code
                CurrentQuantity    = [decimal]$holding.quantity
                TotalCost          = [math]::Round($totalCost, 2)
                AverageCostPerUnit = [math]::Round($avgCost, 8)
            }
        }

        return $results
    }
 
 };

