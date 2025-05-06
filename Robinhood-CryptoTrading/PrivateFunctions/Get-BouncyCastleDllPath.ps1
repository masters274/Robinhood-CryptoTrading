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
 
 };

