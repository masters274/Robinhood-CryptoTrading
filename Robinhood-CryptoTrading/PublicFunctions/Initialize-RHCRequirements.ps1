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

    if (-not (Test-RHCEulaAccepted)) {

        $eulaAccepted = Initialize-RHCEula

        if (-not $eulaAccepted) {
            throw "EULA not accepted. Robinhood Crypto functions cannot be used."
        }
    }

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


    return $true
 
 };

