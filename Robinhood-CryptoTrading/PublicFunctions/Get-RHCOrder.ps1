function Get-RHCOrder { 
 
    <#
        .SYNOPSIS
            Retrieves cryptocurrency order information from a Robinhood account.

        .DESCRIPTION
            This function makes an authenticated request to the Robinhood Crypto API to retrieve
            information about cryptocurrency orders. It can retrieve either a specific order by ID
            or multiple orders based on query parameters (such as state, side, or symbol).

        .PARAMETER ApiKey
            The API key for authenticating with the Robinhood Crypto API.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER PrivateKeySeed
            The private key seed used for signing the API request.
            If not specified, it will be retrieved from stored credentials.

        .PARAMETER BaseUrl
            The base URL for the Robinhood API. Defaults to "https://trading.robinhood.com".

        .PARAMETER OrderId
            The unique identifier of a specific order to retrieve. When specified, the function
            returns details for only this order. If omitted, the function retrieves all orders.

        .PARAMETER QueryParameters
            A hashtable containing query parameters to filter the orders. Common parameters include:
            - state: Filter by order state (e.g., "filled", "canceled", "pending")
            - side: Filter by order side ("buy" or "sell")
            - symbol: Filter by trading pair symbol (e.g., "BTC-USD")
            - start_time: Filter by orders after this time
            - end_time: Filter by orders before this time

        .EXAMPLE
            Get-RHCOrder

            Returns all orders using stored credentials.

        .EXAMPLE
            Get-RHCOrder -OrderId "1234abcd-5678-efgh-9012-ijkl3456mnop"

            Returns information about a specific order with the given ID.

        .EXAMPLE
            Get-RHCOrder -QueryParameters @{state = "filled"; symbol = "BTC-USD"}

            Returns all filled Bitcoin orders.

        .EXAMPLE
            Get-RHCOrder -QueryParameters @{side = "buy"; state = "pending"}

            Returns all pending buy orders.

        .OUTPUTS
            Returns a PSCustomObject containing order information from the Robinhood Crypto API.

        .NOTES
            This function requires valid Robinhood Crypto API credentials and the BouncyCastle cryptography library.
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByQuery')]
    Param(
        # Common parameters
        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed),

        [Parameter(Mandatory = $false)]
        [string] $BaseUrl = "https://trading.robinhood.com",

        # Parameter set for retrieving a single order
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [string] $OrderId,

        # Parameter set for retrieving orders by query
        [Parameter(Mandatory = $false, ParameterSetName = 'ByQuery', HelpMessage = '# Optional query parameters as a hashtable (e.g., Get-RHCOrder -QueryParameters @{state = "filled"})')]
        [hashtable] $QueryParameters
    )

    Begin {
        Initialize-RHCRequirements | Out-Null
    }

    Process {

        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                $path = "/api/v1/crypto/trading/orders/$OrderId/"
            }
            'ByQuery' {
                $query = ""
                if ($QueryParameters) {
                    $query = Build-RHCQueryString -Parameters $QueryParameters
                }
                $path = "/api/v1/crypto/trading/orders/$query"
            }
        }

        $msg = [RHMessage]::new($ApiKey, $path, "GET", $null)

        if (-not $msg.IsValid()) {
            throw "RHMessage is not valid. Please check that ApiKey, Path, and Method (and Body for non-GET) are set."
        }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
 
 };

