
#region EULA


$eulaAcceptedMarkerDir = Join-Path $env:LOCALAPPDATA "RobinhoodCryptoTrading"

$eulaAcceptedMarkerPath = Join-Path $eulaAcceptedMarkerDir "EulaAccepted.txt"

$moduleName = $MyInvocation.MyCommand.Name

if (-not (Test-Path $eulaAcceptedMarkerPath)) {

    $eulaText = @"
===============================================================================
END USER LICENSE AGREEMENT FOR Robinhood-CryptoTrading PowerShell Module
===============================================================================

IMPORTANT: PLEASE READ THIS AGREEMENT CAREFULLY BEFORE USING THIS SOFTWARE.

BY USING THIS SOFTWARE, YOU AGREE TO BE BOUND BY THE TERMS OUTLINED BELOW.

1. LICENSE:
   This software is licensed under the MIT License. You can view the full
   license terms here:
   https://github.com/masters274/Robinhood-CryptoTrading/blob/main/LICENSE

2. DISCLAIMER:
   Please review the important disclaimer regarding the use of this software
   and the risks associated with cryptocurrency trading:
   https://github.com/masters274/Robinhood-CryptoTrading/blob/main/DISCLAIMER.md

   Trading cryptocurrencies involves significant risk. The author is not
   liable for any financial losses incurred using this software. Use at your
   own risk.

3. GETTING STARTED:
   For instructions on how to setup this module, please refer to the README file:
   https://github.com/masters274/Robinhood-CryptoTrading/blob/main/README.md

4. ACCEPTANCE:
   By typing 'yes' below and continuing to use this software, you acknowledge
   that you have read, understood, and agree to be bound by the MIT License
   and the terms stated in the Disclaimer.

   If you do not agree to these terms, type 'no' to decline, and do not use
   the software. The module will not load.
===============================================================================
"@


    Write-Host $eulaText -ForegroundColor Yellow
    Write-Host ""

    # Prompt for acceptance
    $accepted = $false
    while (-not $accepted) {

        $response = Read-Host "Do you accept the terms of the EULA? (Enter 'yes' to accept or 'no' to decline)"

        if ($response -eq 'yes') {

            try {

                if (-not (Test-Path $eulaAcceptedMarkerDir)) {

                    New-Item -ItemType Directory -Path $eulaAcceptedMarkerDir -Force -ErrorAction Stop | Out-Null
                }

                Set-Content -Path $eulaAcceptedMarkerPath -Value "Accepted on $(Get-Date -Format 'u')" -Force -ErrorAction Stop

                Write-Host "EULA accepted. The Robinhood Crypto module will now load." -ForegroundColor Green

                $accepted = $true
            }
            catch {

                Write-Error "Could not save EULA acceptance status to '$eulaAcceptedMarkerPath'. Error: $($_.Exception.Message)"

                throw "Module '$moduleName' cannot be loaded due to failure saving EULA acceptance."
            }
        }
        elseif ($response -eq 'no') {

            throw "EULA not accepted. Module '$moduleName' cannot be loaded."
        }
        else {

            Write-Warning "Invalid input. Please enter 'yes' or 'no'."
        }
    }
}


#endregion


#region Classes


class RHMessage {
    [string] $ApiKey
    [string] $Path
    [string] $Method
    [string] $Body
    [Int64] $Timestamp
    [string] $Signature

    # Constructor: sets up the message properties and automatically assigns a current timestamp.
    RHMessage([string] $ApiKey = [string] $ApiKey, [string] $path, [string] $method, [string] $body = "") {
        $this.ApiKey = $apiKey
        $this.Path = $path
        $this.Method = $method
        $this.Body = $body
        $this.Timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }

    # The Sign method uses BouncyCastle to sign the message.
    [void] Sign([string] $privateKeySeed) {
        # Construct the message to be signed.
        # Format: ApiKey + Timestamp + Path + Method + Body
        $messageToSign = "$($this.ApiKey)$($this.Timestamp)$($this.Path)$($this.Method)$($this.Body)"
        $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($messageToSign)

        try {
            # Convert the Base64-encoded private key seed to a byte array.
            $privateKeySeedBytes = [Convert]::FromBase64String($privateKeySeed)
        }
        catch {
            throw "Invalid private key seed: not a valid Base64 string."
        }

        try {
            # Create an Ed25519 private key parameter using the provided seed.
            $privateKeyParams = New-Object Org.BouncyCastle.Crypto.Parameters.Ed25519PrivateKeyParameters($privateKeySeedBytes, 0)
        }
        catch {
            throw "Error creating Ed25519 private key parameters: $_"
        }

        try {
            # Instantiate the Ed25519Signer.
            $signer = New-Object Org.BouncyCastle.Crypto.Signers.Ed25519Signer
            # Initialize the signer for signing.
            $signer.Init($true, $privateKeyParams)
            # Feed the message bytes into the signer.
            $signer.BlockUpdate($messageBytes, 0, $messageBytes.Length)
            # Generate the signature as a byte array.
            $signatureBytes = $signer.GenerateSignature()
            # Convert the signature to a Base64 string.
            $this.Signature = [Convert]::ToBase64String($signatureBytes)
        }
        catch {
            throw "Error signing the message: $_"
        }
    }

    # Returns a hashtable containing the headers for an API call.
    [hashtable] GetHeaders() {
        return @{
            "x-api-key"    = $this.ApiKey
            "x-timestamp"  = "$($this.Timestamp)"
            "x-signature"  = $this.Signature
            "Content-Type" = "application/json; charset=utf-8"
        }
    }

    # Validates that the RHMessage has all required fields.
    # For GET requests, Body can be empty; for other methods, Body must be non-empty.
    [bool] IsValid() {
        if ([string]::IsNullOrWhiteSpace($this.ApiKey)) { return $false }
        if ([string]::IsNullOrWhiteSpace($this.Path)) { return $false }
        if ([string]::IsNullOrWhiteSpace($this.Method)) { return $false }
        if ($this.Method.ToUpper() -ne "GET" -and [string]::IsNullOrWhiteSpace($this.Body)) { return $false }
        return $true
    }
}


#endregion


#region Setup


<#
    Windows libraries don't natively support Ed25519, so we need to use a third-party library. BouncyCastle
#>

function New-RHCKeyPair {
    <#
        .SYNOPSIS
            Generates a new Ed25519 key pair for use with Robinhood Crypto API.

        .DESCRIPTION
            This function creates a new Ed25519 key pair using the BouncyCastle cryptography library.
            It returns a PSCustomObject containing the private key and public key as Base64-encoded strings.
            The private key is used for signing API requests, while the public key can be registered with Robinhood.

        .EXAMPLE
            $keyPair = New-RHCKeyPair
            $keyPair.PrivateKey  # View the Base64-encoded private key
            $keyPair.PublicKey   # View the Base64-encoded public key

        .EXAMPLE
            $keyPair = New-RHCKeyPair

        .NOTES
            The Ed25519 algorithm is used for digital signatures. The private key is sensitive information
            and should be stored securely. The BouncyCastle.NetCore package is required and will be
            installed automatically if needed.

        .OUTPUTS
            [PSCustomObject] with properties:
            - PrivateKey: Base64-encoded private key string
            - PublicKey: Base64-encoded public key string
    #>

    [CmdletBinding()]
    Param ()

    Begin {

        Initialize-RHCRequirements | Out-Null
    }

    Process {

        try {
            # Create a SecureRandom instance.
            $secureRandom = New-Object Org.BouncyCastle.Security.SecureRandom

            # Create an instance of the Ed25519 key pair generator.
            $generator = New-Object Org.BouncyCastle.Crypto.Generators.Ed25519KeyPairGenerator

            # Initialize the generator with key generation parameters.
            $genParams = New-Object Org.BouncyCastle.Crypto.Parameters.Ed25519KeyGenerationParameters($secureRandom)
            $generator.Init($genParams)

            # Generate the key pair.
            $keyPair = $generator.GenerateKeyPair()

            # Extract the private and public key parameters.
            $privateKey = $keyPair.Private
            $publicKey = $keyPair.Public

            # Get the encoded byte arrays for each key.
            $privBytes = $privateKey.GetEncoded()
            $pubBytes = $publicKey.GetEncoded()

            # Convert the byte arrays to Base64 strings.
            $privateKeyBase64 = [Convert]::ToBase64String($privBytes)
            $publicKeyBase64 = [Convert]::ToBase64String($pubBytes)

            # Return the keys as a custom object.
            return [PSCustomObject]@{
                PrivateKey = $privateKeyBase64
                PublicKey  = $publicKeyBase64
            }
        }
        catch {
            Write-Error "Error generating key pair: $_"
            return $null
        }
    }
}


function Initialize-RHCRequirements {
    <#
        .SYNOPSIS
            Initializes the requirements for Robinhood Crypto trading.

        .DESCRIPTION
            This function ensures that the BouncyCastle cryptography library is properly loaded into the current
            session. It checks for the presence of the BouncyCastle.Crypto assembly, attempts to load it if
            available, and provides information about the loading process.

        .PARAMETER Force
            If specified, forces the reinstallation of package dependencies without confirmation prompts.

        .EXAMPLE
            Initialize-RHCRequirements

            Checks if BouncyCastle.Crypto is available and loads it into the current session.

        .EXAMPLE
            Initialize-RHCRequirements -Force

            Forces the reinstallation of the BouncyCastle.NetCore package and loads it into the current session.

        .EXAMPLE
            Initialize-RHCRequirements -Verbose

            Provides detailed information about the initialization process, including where the assembly is loaded from.

        .OUTPUTS
            [System.Boolean]
            Returns $true if initialization was successful, $null if it failed.
    #>

    [CmdletBinding()]
    Param (
        [switch] $Force
    )

    Write-Verbose "Initializing Robinhood Requirements..."
    # Call Test-RHCRequirements to check/install BouncyCastle.NetCore and obtain the DLL path.
    $bouncyDllPath = Test-RHCRequirements -Force:$Force
    if (-not $bouncyDllPath) {
        Write-Error "BouncyCastle.Crypto DLL could not be found or installed."
        return $null
    }

    Write-Verbose "Loading BouncyCastle.Crypto assembly from '$bouncyDllPath'..."
    try {
        Add-Type -Path $bouncyDllPath -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to load BouncyCastle.Crypto assembly from '$bouncyDllPath': $_"
        return $null
    }

    Write-Verbose "BouncyCastle.Crypto successfully loaded."
    # Place any additional initialization here if needed.

    return $true
}


function Remove-RHCCredentials {
    <#
    .SYNOPSIS
        Removes the stored Robinhood Crypto Trading credentials from environment variables.

    .DESCRIPTION
        This function removes the encrypted Robinhood Crypto Trading credentials (API key and private key seed)
        from both the current session's environment variables and from the persistent user environment variables
        stored in the registry.

    .EXAMPLE
        Remove-RHCCredentials

        Removes all stored Robinhood Crypto Trading credentials from the environment.
    #>

    [CmdletBinding()]
    Param ()

    $apiKeyVarName = 'RobinhoodCryptoApiKey'
    $privateKeyVarName = 'RobinhoodCryptoPrivateKey'

    if (Test-Path -Path ("env:{0}" -f $apiKeyVarName)) {
        Remove-Item -Path ("env:{0}" -f $apiKeyVarName)
        Remove-ItemProperty -Path "HKCU:\Environment" -Name $apiKeyVarName
    }

    if (Test-Path -Path ("env:{0}" -f $privateKeyVarName)) {
        Remove-Item -Path ("env:{0}" -f $privateKeyVarName)
        Remove-ItemProperty -Path "HKCU:\Environment" -Name $privateKeyVarName
    }
}


function Save-RHCCredentials {
    <#
    .SYNOPSIS
        Stores Robinhood Crypto Trading credentials in encrypted environment variables.

    .DESCRIPTION
        This function securely stores Robinhood Crypto Trading credentials (private key seed and API key)
        in persistent environment variables.

    .PARAMETER PrivateKeySeed
        The private key seed for Robinhood Crypto Trading.

    .PARAMETER ApiKey
        The API key for Robinhood Crypto Trading.

    .EXAMPLE
        Save-RobinhoodCredentials -PrivateKeySeed "your-private-key-seed" -ApiKey "your-api-key"

    .NOTES
        Storing credentials in an environment variable helps with automation of crypto trading.
        Consider placing IP restrictions on the API key to limit access to your account if storing credentials.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [string] $ApiKey = $(Get-RHCCredentials -ApiKey),

        [Parameter(Mandatory = $false)]
        [string] $PrivateKeySeed = $(Get-RHCCredentials -PrivateKeySeed)
    )

    $apiKeyVarName = 'RobinhoodCryptoApiKey'
    $privateKeyVarName = 'RobinhoodCryptoPrivateKey'

    $ApiKeySecureString = (
        ([PSCredential]::new('temp', ($ApiKey | ConvertTo-SecureString -AsPlainText -Force))).Password |
        ConvertFrom-SecureString
    )

    $PrivateKeySecureString = (
        ([PSCredential]::new('temp', ($PrivateKeySeed | ConvertTo-SecureString -AsPlainText -Force))).Password |
        ConvertFrom-SecureString
    )

    Remove-RHCCredentials -ErrorAction SilentlyContinue

    Invoke-EnvironmentalVariable -Name $apiKeyVarName -Value $ApiKeySecureString -Scope User -Action New
    Invoke-EnvironmentalVariable -Name $privateKeyVarName -Value $PrivateKeySecureString -Scope User -Action New

    # When making a new environment variable, it is necessary to reload the profile to make it available.
    # This will make them available now
    Invoke-EnvironmentalVariable -Name $apiKeyVarName -Value $ApiKeySecureString -Scope Process -Action New
    Invoke-EnvironmentalVariable -Name $privateKeyVarName -Value $PrivateKeySecureString -Scope Process -Action New
}


function Get-RHCCredentials {
    <#
        .SYNOPSIS
            Retrieves encrypted Robinhood Crypto Trading credentials from environment variables.

        .DESCRIPTION
            This function retrieves the encrypted Robinhood Crypto Trading credentials (API key and private key seed)
            from environment variables and decrypts them for use. If the credentials are not found in the
            environment variables, it prompts the user to enter them.

        .PARAMETER ApiKey
            Switch parameter. When specified, returns only the API key.

        .PARAMETER PrivateKeySeed
            Switch parameter. When specified, returns only the private key seed.

        .EXAMPLE
            Get-RHCCredentials
            Returns both the API key and private key seed as a PSCustomObject.

        .EXAMPLE
            Get-RHCCredentials -ApiKey
            Returns only the API key.

        .EXAMPLE
            Get-RHCCredentials -PrivateKeySeed
            Returns only the private key seed.
    #>

    [CmdletBinding()]
    Param (
        [switch] $ApiKey,

        [switch] $PrivateKeySeed
    )

    try {
        $aKeyPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode(($env:RobinhoodCryptoApiKey | ConvertTo-SecureString -ErrorAction SilentlyContinue))

        $aKey = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($aKeyPtr)


        $pKeyPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode(($env:RobinhoodCryptoPrivateKey | ConvertTo-SecureString -ErrorAction SilentlyContinue))

        $pKey = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($pKeyPtr)
    }
    catch {
        if ($ApiKey) {
            return Read-Host -AsSecureString -Prompt "Enter your Robinhood Crypto API Key"
        }

        if ($PrivateKeySeed) {
            return Read-Host - AsSecureString -Prompt "Enter your Robinhood Crypto Private Key"
        }

        return $null
    }
    finally {
        # Always free the unmanaged memory to reduce exposure of sensitive data.
        if ($apiKeyPtr <# -ne [IntPtr]::Zero #>) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($apiKeyPtr)
        }
        if ($pkeyPtr <# -ne [IntPtr]::Zero #>) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($pkeyPtr) | Out-Null
        }
    }

    if ($ApiKey) {
        return $aKey
    }
    elseif ($PrivateKeySeed) {
        return $pKey
    }
    else {
        return [PSCustomObject]@{
            ApiKey         = $aKey
            PrivateKeySeed = $pKey
        }
    }
}


#endregion


#region Public Functions


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
}


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
}


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
}


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
}


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
}


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

    [CmdletBinding(DefaultParameterSetName = 'Market')]
    Param (

        [Parameter(Mandatory = $true)]
        [ValidateSet("buy", "sell")]
        [string] $Side,

        [Parameter(Mandatory = $true)]
        [string] $Symbol,

        [Parameter(Mandatory = $true)]
        [string] $AssetQuantity,

        [Parameter(Mandatory = $true, ParameterSetName = 'Limit')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StopLoss')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StopLimit')]
        [string] $QuoteAmount,

        [Parameter(Mandatory = $true, ParameterSetName = 'Limit', HelpMessage = 'gtc = Good Till Cancelled, day = Day Order')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StopLoss', HelpMessage = 'gtc = Good Till Cancelled, day = Day Order')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StopLimit', HelpMessage = 'gtc = Good Till Cancelled, day = Day Order')]
        [ValidateSet("gtc", "day")]
        [string] $TimeInForce,

        [Parameter(Mandatory = $true, ParameterSetName = 'Limit')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StopLimit')]
        [string] $LimitPrice,

        [Parameter(Mandatory = $true, ParameterSetName = 'StopLoss')]
        [Parameter(Mandatory = $true, ParameterSetName = 'StopLimit')]
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

        if (-not $ClientOrderId) {
            $ClientOrderId = [guid]::NewGuid().ToString()
        }

        $payload = @{
            client_order_id = $ClientOrderId
            side            = $Side
            symbol          = $Symbol
        }

        switch ($PSCmdlet.ParameterSetName) {
            'Market' {
                $payload.Add("type", "market")
                $payload.Add("market_order_config", @{ asset_quantity = $AssetQuantity })
            }
            'Limit' {
                $payload.Add("type", "limit")
                $payload.Add("limit_order_config", @{
                        asset_quantity = $AssetQuantity
                        quote_amount   = $QuoteAmount
                        limit_price    = $LimitPrice
                        time_in_force  = $TimeInForce
                    })
            }
            'StopLoss' {
                $payload.Add("type", "stop_loss")
                $payload.Add("stop_loss_order_config", @{
                        asset_quantity = $AssetQuantity
                        quote_amount   = $QuoteAmount
                        stop_price     = $StopPrice
                        time_in_force  = $TimeInForce
                    })
            }
            'StopLimit' {
                $payload.Add("type", "stop_limit")
                $payload.Add("stop_limit_order_config", @{
                        asset_quantity = $AssetQuantity
                        quote_amount   = $QuoteAmount
                        stop_price     = $StopPrice
                        limit_price    = $LimitPrice
                        time_in_force  = $TimeInForce
                    })
            }
        }

        $jsonBody = $payload | ConvertTo-Json -Depth 5

        $path = "/api/v1/crypto/trading/orders/"

        $msg = [RHMessage]::new($ApiKey, $path, "POST", $jsonBody)
        if (-not $msg.IsValid()) {
            throw "RHMessage is not valid."
        }

        $msg.Sign($PrivateKeySeed)

        return Send-RHCRequest -RHMessage $msg -BaseUrl $BaseUrl
    }
}


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
}


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
}


#endregion


#region Private Functions


function Build-RHCQueryString {

    Param (
        [hashtable] $Parameters
    )

    if (-not $Parameters -or $Parameters.Count -eq 0) {
        return ""
    }

    $queryParts = @()

    foreach ($key in $Parameters.Keys) {

        $value = $Parameters[$key]

        # If the value is an array (but not a string), add a key=value pair for each element.
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {

            foreach ($item in $value) {
                $queryParts += ([System.Uri]::EscapeDataString($key) + "=" + [System.Uri]::EscapeDataString($item))
            }
        }
        else {

            $queryParts += ([System.Uri]::EscapeDataString($key) + "=" + [System.Uri]::EscapeDataString($value))
        }
    }

    return "?" + ($queryParts -join "&")
}


function Expand-BouncyCastlePackage {
    [CmdletBinding()]
    Param ()

    try {
        $pkg = Get-Package -Name "BouncyCastle.NetCore" -ErrorAction Stop
    }
    catch {
        Write-Error "Could not retrieve package information for BouncyCastle.NetCore: $_"
        return $null
    }

    # The Source property should point to the .nupkg file.
    $nupkgPath = $pkg.Source

    if (-not (Test-Path $nupkgPath)) {
        Write-Error "The nupkg file '$nupkgPath' does not exist."
        return $null
    }

    # Define an extraction folder adjacent to the nupkg file.
    $extractDir = Join-Path (Split-Path $nupkgPath) "BouncyCastle.NetCore"

    if (-not (Test-Path $extractDir)) {
        try {
            Expand-Archive -Path $nupkgPath -DestinationPath $extractDir -Force -ErrorAction Stop
            Write-Verbose "Extracted BouncyCastle.NetCore package to: $extractDir"
        }
        catch {
            Write-Error "Failed to extract package from '$nupkgPath': $_"
            return $null
        }
    }

    return $extractDir
}


function Get-BouncyCastleDllPath {
    [CmdletBinding()]
    Param (
        # Optionally provide a search path; by default, use the package directory.
        [string] $SearchPath = (Get-PackageDirectory)
    )

    # Look for version directories (sorted descending so that the highest version is used first)
    $versionDirs = Get-ChildItem -Path $SearchPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending

    foreach ($dir in $versionDirs) {
        # Recursively search within the version directory for the DLL file.
        $dllFile = Get-ChildItem -Path $dir.FullName -Filter "BouncyCastle.Crypto.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($dllFile) {
            return $dllFile.FullName
        }
    }

    return $null
}


function Get-PackageDirectory {
    # Retrieves the package directory from the installed BouncyCastle.NetCore package.
    $nupkgPath = (Get-Package -Name BouncyCastle.NetCore).Source
    [String] (Get-ChildItem -Path $nupkgPath).DirectoryName
}


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
}


function Test-RHCRequirements {
    [CmdletBinding()]
    Param (
        # If specified, installation will occur without prompting for confirmation.
        [switch] $Force
    )

    Write-Verbose "Checking if BouncyCastle is already loaded in the current AppDomain..."
    $loadedAssembly = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq "BouncyCastle.Crypto" }
    if ($loadedAssembly) {
        Write-Verbose "BouncyCastle is already loaded at: $($loadedAssembly.Location)"
        return $loadedAssembly.Location
    }

    # Attempt to get package information. Only if this fails will we try to install.
    $pkg = $null
    try {
        $pkg = Get-Package -Name "BouncyCastle.NetCore" -ErrorAction Stop
        Write-Verbose "BouncyCastle.NetCore package is already installed. Version: $($pkg.Version)"
    }
    catch {
        Write-Verbose "BouncyCastle.NetCore package is not installed."
    }

    # Define the expected global NuGet packages folder for BouncyCastle.NetCore.
    $globalPackagesFolder = Join-Path $env:USERPROFILE ".nuget\packages\bouncycastle.netcore"
    if (Test-Path $globalPackagesFolder) {
        Write-Verbose "BouncyCastle.NetCore package folder found at: $globalPackagesFolder"
        $dllPath = Get-BouncyCastleDllPath -SearchPath $globalPackagesFolder
        if ($dllPath) {
            Write-Verbose "Found BouncyCastle.Crypto.dll at: $dllPath"
            return $dllPath
        }
    }
    else {
        Write-Verbose "Global packages folder '$globalPackagesFolder' not found."
    }

    # Only install the package if Get-Package did not return package information.
    if (-not $pkg) {
        Write-Verbose "BouncyCastle.NetCore does not appear to be installed. Checking for NuGet package source 'nuget.org'..."

        # Ensure that the nuget.org package source is registered.
        $nugetSource = Get-PackageSource -Name "nuget.org" -ErrorAction SilentlyContinue
        if (-not $nugetSource) {
            Write-Verbose "NuGet.org package source not found. Attempting to register it..."
            try {
                Register-PackageSource -Name "nuget.org" `
                    -ProviderName "NuGet" `
                    -Location "https://api.nuget.org/v3/index.json" `
                    -Trusted -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to register NuGet.org package source: $_"
                return $null
            }
        }

        Write-Verbose "Installing BouncyCastle.NetCore package via NuGet..."
        if (-not (Get-Command Install-Package -ErrorAction SilentlyContinue)) {
            Write-Error "Install-Package command not found. Please ensure PackageManagement is installed."
            return $null
        }

        try {
            # Build the common parameter hash table for splatting.
            $installParams = @{
                Name         = "BouncyCastle.NetCore"
                ProviderName = "NuGet"
                Scope        = "CurrentUser"
                ErrorAction  = "Stop"
            }

            # If the Force switch is set, add the extra parameters.
            if ($Force) {
                Write-Verbose "Force flag set. Installing without confirmation."
                $installParams += @{
                    Force   = $true
                    Confirm = $false
                }
            }

            # Use splatting to call Install-Package with the assembled parameters.
            Install-Package @installParams
        }
        catch {
            Write-Error "Failed to install the BouncyCastle.NetCore NuGet package: $_"
            return $null
        }
    }
    else {
        Write-Verbose "BouncyCastle.NetCore package already installed. Skipping installation."
    }

    # After installation (or if already installed), check again for the DLL in the global packages folder.
    if (Test-Path $globalPackagesFolder) {
        $dllPath = Get-BouncyCastleDllPath -SearchPath $globalPackagesFolder
        if ($dllPath) {
            Write-Verbose "BouncyCastle.Crypto.dll located at: $dllPath after installation."
            return $dllPath
        }
    }

    # If still not found, try extracting the package.
    Write-Verbose "BouncyCastle.Crypto.dll not found in the package folder; attempting to extract the nupkg..."
    $extractedPath = Expand-BouncyCastlePackage
    if ($extractedPath) {
        $dllPath = Get-BouncyCastleDllPath -SearchPath $extractedPath
        if ($dllPath) {
            Write-Verbose "BouncyCastle.Crypto.dll located at: $dllPath after extraction."
            return $dllPath
        }
    }

    Write-Error "BouncyCastle.NetCore installation completed, but the DLL could not be located even after extraction."
    return $null
}


#endregion
