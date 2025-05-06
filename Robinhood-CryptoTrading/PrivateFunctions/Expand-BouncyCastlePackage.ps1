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
 
 };

