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
 
 };

