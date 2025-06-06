@{
    ModuleVersion     = '1.0.0'
    GUID              = 'e1aad6cb-6f3d-4e62-8031-56d6f3e60049'
    Author            = 'Chris Masters'
    CompanyName       = 'Chris Masters'
    Copyright         = '(c) 2025 Chris Masters. All rights reserved.'
    Description       = 'Module for interacting with the Robinhood Crypto API using BouncyCastle for cryptographic operations.'
    RootModule        = 'Robinhood-CryptoTrading.psm1'
    PowerShellVersion = '5.1'
    RequiredModules   = @(
        @{ModuleName = 'core'; Guid = '7ffd438f-134c-49be-8000-9a9f3af1cbe3'; ModuleVersion = '1.9.4.2' }
    )

    FunctionsToExport = @(
        'New-RHCKeyPair',
        'Initialize-RHCRequirements',
        'Remove-RHCCredentials',
        'Save-RHCCredentials',
        'Get-RHCCredentials',
        'Get-RHCAccount',
        'Get-RHCBestBidAsk',
        'Get-RHCEstimatedPrice',
        'Get-RHCHoldings',
        'Get-RHCTradingPairs',
        'New-RHCOrder',
        'Stop-RHCOrder',
        'Get-RHCOrder',
        'Get-RHCCostBasisSummary'
    )

    PrivateData       = @{

        PSData = @{

            Tags                     = @('Robinhood', 'RobinhoodCrypto', 'Crypto', 'Cryptocurrency', 'Trading', 'API', 'Finance', 'Investing', 'Investment')
            LicenseUri               = 'https://github.com/masters274/Robinhood-CryptoTrading/blob/main/LICENSE'
            ProjectUri               = 'https://github.com/masters274/Robinhood-CryptoTrading'
            RepositorySourceLocation = 'https://github.com/masters274/Robinhood-CryptoTrading/tree/main/Robinhood-CryptoTrading'
            IconUri                  = 'https://github.com/masters274/Robinhood-CryptoTrading/blob/main/images/rhc_icon.png'
            HelpUri                  = 'https://github.com/masters274/Robinhood-CryptoTrading/blob/main/README.md'
            RequireLicenseAcceptance = $true
            ReleaseNotes             = '
Version 0.1
- Day 1 release of Robinhood Crypto Trading module.

Version 1.0.0
- Manifest file updated with URLs, and removed empty exporters
- Repo updates: images directory with icon image uploaded. README file updated. Coffee link added
'
        }
    }
}
