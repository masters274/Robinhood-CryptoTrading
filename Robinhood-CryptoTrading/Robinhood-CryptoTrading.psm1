<#
    .SYNOPSIS
        Root module file for Robinhood Crypto Trading

    .DESCRIPTION
        This module provides functions to interact with the Robinhood Crypto Trading API

    .NOTES
        Author: Chris Masters
        Tags: Robinhood, RobinhoodCrypto, Crypto, Cryptocurrency, Trading, API, Finance, Investing, Investment
#>


#region EULA


function Test-RHCEulaAccepted {
    <#
    .SYNOPSIS
        Checks if the EULA has been accepted.

    .DESCRIPTION
        Verifies if the EULA has been accepted by checking for the presence of a marker file
        or the existence of an environment variable.

    .OUTPUTS
        [System.Boolean] Returns $true if the EULA has been accepted, $false otherwise.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    $eulaAcceptedMarkerDir = Join-Path $env:LOCALAPPDATA "RobinhoodCryptoTrading"
    $eulaAcceptedMarkerPath = Join-Path $eulaAcceptedMarkerDir "EulaAccepted.txt"

    return (Test-Path $eulaAcceptedMarkerPath)
}


function Set-RHCEulaAccepted {
    <#
    .SYNOPSIS
        Marks the EULA as accepted.

    .DESCRIPTION
        Creates a marker file indicating that the EULA has been accepted.

    .PARAMETER Force
        If specified, creates the marker file without prompting for confirmation.

    .OUTPUTS
        [System.Boolean] Returns $true if the operation was successful, $false otherwise.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [switch]$Force
    )

    $eulaAcceptedMarkerDir = Join-Path $env:LOCALAPPDATA "RobinhoodCryptoTrading"
    $eulaAcceptedMarkerPath = Join-Path $eulaAcceptedMarkerDir "EulaAccepted.txt"

    try {
        if (-not (Test-Path $eulaAcceptedMarkerDir)) {
            New-Item -ItemType Directory -Path $eulaAcceptedMarkerDir -Force -ErrorAction Stop | Out-Null
        }

        Set-Content -Path $eulaAcceptedMarkerPath -Value "Accepted on $(Get-Date -Format 'u')" -Force -ErrorAction Stop

        if (-not $Force) {
            Write-Host "EULA accepted. The Robinhood Crypto module will now load." -ForegroundColor Green
        }

        return $true
    }
    catch {
        Write-Error "Could not save EULA acceptance status to '$eulaAcceptedMarkerPath'. Error: $($_.Exception.Message)"
        return $false
    }
}


function Show-RHCEulaPrompt {
    <#
    .SYNOPSIS
        Shows the EULA prompt and waits for user acceptance.

    .DESCRIPTION
        Displays the EULA text and prompts the user to accept or decline.
        If accepted, records the acceptance.

    .OUTPUTS
        [System.Boolean] Returns $true if the EULA was accepted, $false otherwise.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    $moduleName = $MyInvocation.MyCommand.Module.Name

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
   that you have read, understood, and agree to be bound by the MIT License (1)
   and the terms stated in the Disclaimer(2).

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
            $accepted = Set-RHCEulaAccepted
            return $true
        }
        elseif ($response -eq 'no') {
            Write-Warning "EULA not accepted. Module '$moduleName' cannot be used."
            return $false
        }
        else {
            Write-Warning "Invalid input. Please enter 'yes' or 'no'."
        }
    }

    return $false
}


function Initialize-RHCEula {
    <#
    .SYNOPSIS
        Initializes the EULA acceptance process.

    .DESCRIPTION
        Checks if the EULA has been accepted, and if not, handles the acceptance process
        through either environment variables or by prompting the user.

    .OUTPUTS
        [System.Boolean] Returns $true if the EULA was accepted, $false otherwise.
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    Param()

    if (Test-RHCEulaAccepted) {
        return $true
    }

    if ($env:RHC_EULA_ACCEPTED -eq 'yes') {
        return Set-RHCEulaAccepted -Force
    }

    return Show-RHCEulaPrompt
}


$eulaAccepted = Initialize-RHCEula

if (-not $eulaAccepted) {
    throw "EULA not accepted. Module cannot be loaded."
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


#region Main


$privateFunctionPath = Join-Path -Path $PSScriptRoot -ChildPath 'PrivateFunctions'
$privateFunctions = @()

if (Test-Path -Path $privateFunctionPath) {

    $privateFunctionFiles = Get-ChildItem -Path $privateFunctionPath -Filter *.ps1


    foreach ($pfile in $privateFunctionFiles) {
        try {
            . $pfile.FullName
            $privateFunctions += $pfile.BaseName
            Write-Verbose "Imported function $($pfile.BaseName)"
        }
        catch {
            Write-Error "Failed to import function $($pfile.FullName): $_"
        }
    }
}
else {
    Write-Warning "No PrivateFunctions directory found at $privateFunctionPath"
}

$publicFunctionPath = Join-Path -Path $PSScriptRoot -ChildPath 'PublicFunctions'
$publicFunctions = @()

if (Test-Path -Path $publicFunctionPath) {

    $functionFiles = Get-ChildItem -Path $publicFunctionPath -Filter *.ps1


    foreach ($file in $functionFiles) {
        try {
            . $file.FullName
            $publicFunctions += $file.BaseName
            Write-Verbose "Imported function $($file.BaseName)"
        }
        catch {
            Write-Error "Failed to import function $($file.FullName): $_"
        }
    }
}
else {
    Write-Warning "No PublicFunctions directory found at $publicFunctionPath"
}

# Export all public functions
Export-ModuleMember -Function $publicFunctions


#endregion
