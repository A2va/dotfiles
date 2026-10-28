#!/usr/bin/env pwsh
#
# Smart `git clone` helper for Windows.
#
# Called with the full argument list of `git clone` by the PowerShell `git`
# function (autoload/git.ps1) or by the Nushell wrapper on Windows.
#
# 1. Rewrites an HTTPS URL to SSH when an identity file for the host exists.
#    The lookup goes through `ssh -G`, so the user's SSH config is honoured.
# 2. After a successful clone, if the repository is a fork, adds an `upstream`
#    remote pointing at the original repository (always over HTTPS) and fetches
#    it.
#
# Environment:
#   SMART_GIT_NO_UPSTREAM=1  disable the fork/upstream lookup
#   SMART_GIT_DEBUG=1        explain what the wrapper is doing
#   SMART_GIT_DRY_RUN=1      print the command instead of running it

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Prog = 'smart-git'

function Write-DebugLog([string]$Message) {
    if ($env:SMART_GIT_DEBUG) {
        [Console]::Error.WriteLine("${Prog}: $Message")
    }
}

function Get-RealGit {
    $cmd = Get-Command -Name 'git.exe' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $cmd) {
        $cmd = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-SshIdentity([string]$HostName) {
    $ssh = Get-Command -Name 'ssh.exe' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $ssh) {
        $ssh = Get-Command -Name 'ssh' -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if (-not $ssh) { return $false }

    try {
        $lines = & $ssh.Source -G $HostName 2>$null
    }
    catch {
        return $false
    }

    foreach ($line in $lines) {
        if ($line -match '^identityfile\s+(.+)$') {
            $file = $Matches[1].Trim().Trim('"')
            if ($file -eq 'none') { continue }
            try {
                $expanded = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($file)
            }
            catch {
                continue
            }
            if (Test-Path -LiteralPath $expanded -PathType Leaf) { return $true }
        }
    }
    return $false
}

function Test-CloneOptionTakesValue([string]$Option) {
    return $Option -in @(
        '-b', '--branch', '-o', '--origin', '-u', '--upload-pack', '--depth',
        '--shallow-since', '--shallow-exclude', '-c', '--config', '--reference',
        '--reference-if-able', '--separate-git-dir', '--filter', '--server-option',
        '--jobs', '-j', '--template', '--bundle-uri', '--revision', '--ref-format'
    )
}

# ---------------------------------------------------------------------------
# Forge adapters. Each returns the HTTPS URL of the original repository.
# ---------------------------------------------------------------------------
function Get-UpstreamGitHub([string]$Path) {
    if (Get-Command -Name 'gh' -ErrorAction SilentlyContinue) {
        try {
            $data = & gh api "repos/$Path" 2>$null | ConvertFrom-Json
        }
        catch {
            return $null
        }
    }
    else {
        try {
            $data = Invoke-RestMethod -Uri "https://api.github.com/repos/$Path" `
                -Headers @{ 'User-Agent' = 'smart-git'; 'Accept' = 'application/vnd.github+json' } `
                -TimeoutSec 10
        }
        catch {
            return $null
        }
    }

    if ($data.fork -and $data.parent.full_name) {
        return "https://github.com/$($data.parent.full_name)"
    }
    return $null
}

function Get-UpstreamGitLab([string]$HostName, [string]$Path) {
    $encoded = [uri]::EscapeDataString($Path)
    try {
        $data = Invoke-RestMethod -Uri "https://$HostName/api/v4/projects/$encoded" `
            -Headers @{ 'Accept' = 'application/json' } -TimeoutSec 10
    }
    catch {
        return $null
    }

    if ($data.forked_from_project.path_with_namespace) {
        return "https://$HostName/$($data.forked_from_project.path_with_namespace)"
    }
    return $null
}

function Get-UpstreamForgejo([string]$HostName, [string]$Path) {
    try {
        $data = Invoke-RestMethod -Uri "https://$HostName/api/v1/repos/$Path" `
            -Headers @{ 'Accept' = 'application/json' } -TimeoutSec 10
    }
    catch {
        return $null
    }

    if ($data.parent.full_name) {
        return "https://$HostName/$($data.parent.full_name)"
    }
    return $null
}

# --- Tangled ---------------------------------------------------------------
# A repository is an `sh.tangled.repo` record in the owner's PDS. A fork
# carries a `source` field with the repo DID of the original; that DID can be
# cloned directly from tangled.org.
function Resolve-TangledDid([string]$Owner) {
    if ($Owner -like 'did:*') { return $Owner }
    $Owner = $Owner.TrimStart('@')
    try {
        $result = Invoke-RestMethod -Uri (
            'https://public.api.bsky.app/xrpc/com.atproto.identity.resolveHandle?handle=' +
            [uri]::EscapeDataString($Owner)
        ) -TimeoutSec 10
    }
    catch {
        return $null
    }
    return $result.did
}

function Get-TangledDidDoc([string]$Did) {
    try {
        if ($Did -like 'did:plc:*') {
            return Invoke-RestMethod -Uri "https://plc.directory/$Did" -TimeoutSec 10
        }
        if ($Did -like 'did:web:*') {
            $domain = $Did.Substring(8) -replace ':', '/'
            return Invoke-RestMethod -Uri "https://$domain/.well-known/did.json" -TimeoutSec 10
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-UpstreamTangled([string]$Path) {
    if ($Path -notmatch '^([^/]+)/([^/]+)$') { return $null }
    $owner = $Matches[1]
    $rkey = $Matches[2]

    $did = Resolve-TangledDid $owner
    if (-not $did) { return $null }

    $doc = Get-TangledDidDoc $did
    if (-not $doc) { return $null }

    $pds = ($doc.service | Where-Object { $_.id -eq '#atproto_pds' } |
        Select-Object -First 1).serviceEndpoint
    if (-not $pds) { return $null }

    $query = "repo=$([uri]::EscapeDataString($did))" +
        '&collection=sh.tangled.repo' +
        "&rkey=$([uri]::EscapeDataString($rkey))"
    try {
        $record = Invoke-RestMethod -Uri "$pds/xrpc/com.atproto.repo.getRecord?$query" -TimeoutSec 10
    }
    catch {
        return $null
    }

    $source = $record.value.source
    if (-not $source) { return $null }

    if ($source -like 'at://*') {
        $parts = $source.Substring(5).Split('/')
        if ($parts.Count -ge 3) { return "https://tangled.org/$($parts[0])/$($parts[2])" }
        return $null
    }
    if ($source -like 'http://*' -or $source -like 'https://*') {
        return $source
    }
    return "https://tangled.org/$source"
}

function Get-UpstreamUrl([string]$HostName, [string]$Path) {
    if ($HostName -eq 'github.com') {
        return Get-UpstreamGitHub $Path
    }
    if ($HostName -eq 'gitlab.com' -or $HostName -like '*gitlab*') {
        return Get-UpstreamGitLab $HostName $Path
    }
    if ($HostName -in @('codeberg.org', 'gitea.com', 'forgejo.org')) {
        return Get-UpstreamForgejo $HostName $Path
    }
    if ($HostName -in @('tangled.org', 'tangled.sh')) {
        return Get-UpstreamTangled $Path
    }

    # Unknown host: probe the two most common self-hosted APIs once.
    $upstream = Get-UpstreamForgejo $HostName $Path
    if ($upstream) { return $upstream }
    return Get-UpstreamGitLab $HostName $Path
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
# Allow the helpers to be dot-sourced for testing without running a clone.
if ($MyInvocation.InvocationName -eq '.') { return }

$realGit = Get-RealGit
if (-not $realGit) {
    [Console]::Error.WriteLine("${Prog}: git not found in PATH")
    exit 127
}

# Find the git subcommand (skipping global options that take a value).
$sub = $null
$subIndex = -1
$skipNext = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($skipNext) { $skipNext = $false; continue }
    if ($a -match '^(-C|-c|--git-dir|--work-tree|--namespace|--exec-path|--config-env)$') {
        $skipNext = $true
        continue
    }
    if ($a -match '^--(git-dir|work-tree|namespace|exec-path|config-env)=') { continue }
    if ($a.StartsWith('-')) { continue }
    $sub = $a
    $subIndex = $i
    break
}

if ($sub -ne 'clone') {
    & $realGit @args
    exit $LASTEXITCODE
}

# Locate the HTTPS URL among the clone arguments.
$url = $null
$urlIndex = -1
for ($i = $subIndex + 1; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($a -match '^https?://') {
        $url = $a
        $urlIndex = $i
        break
    }
}

if (-not $url) {
    & $realGit @args
    exit $LASTEXITCODE
}

$uri = [uri]$url
$hostName = $uri.Host.ToLowerInvariant()
$path = $uri.AbsolutePath.Trim('/') -replace '\.git$', ''

$cloneArgs = [System.Collections.Generic.List[string]]::new()
foreach ($a in $args) { $cloneArgs.Add([string]$a) }

if ($path -and $hostName -and (Test-SshIdentity $hostName)) {
    $sshUrl = "git@${hostName}:$path"
    Write-DebugLog "rewriting $url -> $sshUrl"
    [Console]::Error.WriteLine("${Prog}: using SSH for $hostName")
    $cloneArgs[$urlIndex] = $sshUrl
}

$finalArgs = $cloneArgs.ToArray()

if ($env:SMART_GIT_DRY_RUN) {
    Write-Output ("$realGit " + ($finalArgs -join ' '))
    exit 0
}

& $realGit @finalArgs
$rc = $LASTEXITCODE
if ($rc -ne 0) { exit $rc }

if ($env:SMART_GIT_NO_UPSTREAM) { exit 0 }
if (-not $path -or -not $hostName) { exit 0 }

# Collect the positional arguments of `git clone` (URL and directory).
$clonePos = [System.Collections.Generic.List[string]]::new()
$cloneBare = $false
$endOpts = $false
$skipNext = $false
for ($i = $subIndex + 1; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    if ($skipNext) { $skipNext = $false; continue }
    if ($endOpts) { $clonePos.Add($a); continue }
    if ($a -eq '--') { $endOpts = $true; continue }
    if ($a -in @('--bare', '--mirror')) { $cloneBare = $true; continue }
    if ($a.StartsWith('-')) {
        if (Test-CloneOptionTakesValue $a) { $skipNext = $true }
        continue
    }
    $clonePos.Add($a)
}

if ($cloneBare) { exit 0 }

# `git -C <dir> clone ...` changes the base directory.
$baseDir = (Get-Location).Path
for ($i = 0; $i -lt $subIndex; $i++) {
    if ([string]$args[$i] -eq '-C' -and ($i + 1) -lt $subIndex) {
        $candidate = [string]$args[$i + 1]
        $baseDir = if ([IO.Path]::IsPathRooted($candidate)) {
            $candidate
        }
        else {
            Join-Path $baseDir $candidate
        }
    }
}

$dest = if ($clonePos.Count -ge 2) { $clonePos[1] } else { [IO.Path]::GetFileName($path) }
if (-not $dest) { exit 0 }

$destAbs = if ([IO.Path]::IsPathRooted($dest)) {
    $dest
}
else {
    Join-Path $baseDir $dest
}

& $realGit -C $destAbs rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) { exit 0 }

$upstream = Get-UpstreamUrl $hostName $path
if (-not $upstream) { exit 0 }

& $realGit -C $destAbs remote get-url upstream *> $null
if ($LASTEXITCODE -eq 0) {
    Write-DebugLog 'upstream remote already exists'
    exit 0
}

& $realGit -C $destAbs remote add upstream $upstream
if ($LASTEXITCODE -eq 0) {
    [Console]::Error.WriteLine("${Prog}: added upstream $upstream")
    & $realGit -C $destAbs fetch --quiet upstream *> $null
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("${Prog}: warning: could not fetch upstream")
    }
}

exit 0
