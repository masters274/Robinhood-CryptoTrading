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
 
 };

