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
 
 };

