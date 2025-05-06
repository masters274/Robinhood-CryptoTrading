function New-RHCKeyPair { 
 
    <#
        .SYNOPSIS
            Generates a new Ed25519 key pair for use with Robinhood Crypto API.

        .DESCRIPTION
            This function creates a new Ed25519 key pair using the BouncyCastle cryptography library.
            It returns a PSCustomObject containing the private key and public key as Base64-encoded strings.
            The private key is used for signing API requests, while the public key can be registered with Robinhood.

        .EXAMPLE
            $keyPair = New-RHCKeyPair

            $keyPair.PrivateKey  # View the Base64-encoded private key
            $keyPair.PublicKey   # View the Base64-encoded public key

        .EXAMPLE
            $keyPair = New-RHCKeyPair

        .NOTES
            The Ed25519 algorithm is used for digital signatures. The private key is sensitive information
            and should be stored securely. The BouncyCastle.NetCore package is required and will be
            installed automatically if needed.

        .OUTPUTS
            [PSCustomObject] with properties:
            - PrivateKey: Base64-encoded private key string
            - PublicKey: Base64-encoded public key string
    #>

    [CmdletBinding()]
    Param ()

    Begin {

        Initialize-RHCRequirements | Out-Null
    }

    Process {

        try {
            # Create a SecureRandom instance.
            $secureRandom = New-Object Org.BouncyCastle.Security.SecureRandom

            # Create an instance of the Ed25519 key pair generator.
            $generator = New-Object Org.BouncyCastle.Crypto.Generators.Ed25519KeyPairGenerator

            # Initialize the generator with key generation parameters.
            $genParams = New-Object Org.BouncyCastle.Crypto.Parameters.Ed25519KeyGenerationParameters($secureRandom)
            $generator.Init($genParams)

            # Generate the key pair.
            $keyPair = $generator.GenerateKeyPair()

            # Extract the private and public key parameters.
            $privateKey = $keyPair.Private
            $publicKey = $keyPair.Public

            # Get the encoded byte arrays for each key.
            $privBytes = $privateKey.GetEncoded()
            $pubBytes = $publicKey.GetEncoded()

            # Convert the byte arrays to Base64 strings.
            $privateKeyBase64 = [Convert]::ToBase64String($privBytes)
            $publicKeyBase64 = [Convert]::ToBase64String($pubBytes)

            # Return the keys as a custom object.
            return [PSCustomObject]@{
                PrivateKey = $privateKeyBase64
                PublicKey  = $publicKeyBase64
            }
        }
        catch {
            Write-Error "Error generating key pair: $_"
            return $null
        }
    }
 
 };

