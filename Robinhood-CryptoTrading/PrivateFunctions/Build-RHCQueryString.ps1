function Build-RHCQueryString { 
 

    Param (
        [hashtable] $Parameters
    )

    if (-not $Parameters -or $Parameters.Count -eq 0) {
        return ""
    }

    $queryParts = @()

    foreach ($key in $Parameters.Keys) {

        $value = $Parameters[$key]

        # If the value is an array (but not a string), add a key=value pair for each element.
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {

            foreach ($item in $value) {
                $queryParts += ([System.Uri]::EscapeDataString($key) + "=" + [System.Uri]::EscapeDataString($item))
            }
        }
        else {

            $queryParts += ([System.Uri]::EscapeDataString($key) + "=" + [System.Uri]::EscapeDataString($value))
        }
    }

    return "?" + ($queryParts -join "&")
 
 };

