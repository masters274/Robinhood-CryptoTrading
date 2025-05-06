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
 
 };

