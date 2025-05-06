function Get-PackageDirectory { 
 
    # Retrieves the package directory from the installed BouncyCastle.NetCore package.
    $nupkgPath = (Get-Package -Name BouncyCastle.NetCore).Source
    [String] (Get-ChildItem -Path $nupkgPath).DirectoryName
 
 };

