function ssh-keygen-new {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The name of the key file")]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [Alias('c')]
        [string]$Comment,

        [switch]$NoCopy,

        [switch]$NoAgent
    )

    # Fallback to name if comment is empty
    if ([string]::IsNullOrEmpty($Comment)) {
        $Comment = $Name
    }

    $SshDir = Join-Path $HOME ".ssh"
    $KeyPath = Join-Path $SshDir $Name
    $PubPath = "$KeyPath.pub"

    # Create .ssh folder if it doesn't exist
    if (-not (Test-Path $SshDir)) {
        New-Item -ItemType Directory -Path $SshDir | Out-Null
    }

    # Run ssh-keygen
    & ssh-keygen -t ed25519 -C $Comment -f $KeyPath

    # Check if ssh-keygen succeeded
    if ($LASTEXITCODE -ne 0) {
        Write-Error "ssh-keygen failed with exit code $LASTEXITCODE."
        return
    }

    # Copy public key to clipboard using native PowerShell cmdlets
    if (-not $NoCopy) {
        if (Test-Path $PubPath) {
            Get-Content -Raw $PubPath | Set-Clipboard
            Write-Host "✓ Public key copied to clipboard." -ForegroundColor Green
        } else {
            Write-Warning "Public key file not found at $PubPath"
        }
    }

    # Add key to SSH agent
    if (-not $NoAgent) {
        & ssh-add $KeyPath 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Key added to SSH agent." -ForegroundColor Green
        } else {
            Write-Warning "Failed to add key to SSH agent."
        }
    }
}
