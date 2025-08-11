function cmr {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args,

        [Alias('v')]
        [switch]$Version,

        [Alias('h', 'help')]
        [switch]$ShowHelp
    )

    $scriptVersion = "v20"
    $DEFINITION = "cmr $scriptVersion - (c)make run - binary runner, the missing 'run' command for cmake, make, qb, .."

    function Show-Help {
        Write-Host "$DEFINITION" -ForegroundColor Cyan
        Write-Host "Synopsis: cmr [-v|-h|--help] | [filter arguments] [--] [sub program arguments]"
        Write-Host "How it works ?"
        Write-Host "1. Find executable files under build/ or the folder given as first argument"
        Write-Host "2. Then if there are arguments, they are used to filter this list"
        Write-Host "2.5 If there are still multiple files, it will prompt to choose one via fzf"
        Write-Host "3. Finally, if there are arguments after a '--' argument it will be forwarded to the chosen target"
        Write-Host 
        Write-Host  "Simple execution with a single binary file under build/hello" -ForegroundColor Green
        Show-PowerShellCommand "cmr # just runs ./build/hello"
        Show-PowerShellCommand "cmr -- --name john # just forward arguments after -- and runs ./build/hello --name john"
        
        Write-Host
        Write-Host  "Multiple binary files under a different folder target/ -> target/hello_1 and target/hello_2 and target/goodbye2morrow" -ForegroundColor Green
        Show-PowerShellCommand "cmr target/ # just search under ./target, it will prompt the 3 files via fzf"
        Show-PowerShellCommand "cmr target/ h 2 # just search under ./target and filter the list with fuzzy matching 'h 2' -> it will run ./target/hello_2"
        Show-PowerShellCommand "cmr target/ hello 2 # just search under ./target and filter the list with fuzzy matching 'hello 2' -> it will run ./target/hello_2"
        Show-PowerShellCommand "cmr target/ hello 2 -- --msg byebye # same with 2 arguments forwarded -> it will run ./target/hello_2 --msg byebye"

        Write-Host
        Write-Host "Enable debug mode via CMR_DEBUG variable" -ForegroundColor Green
        Show-PowerShellCommand '$env:CMR_DEBUG=on; cmr target/ hello 2 -- --msg byebye -- # WIP: only arguments separation dump'
    }

    function Show-Help {
        Write-Host "PowerShell script $scriptVersion installed."
    }

    function Show-PowerShellCommand {
        param(
            [Parameter(Mandatory)]
            [string]$Command
        )

        # ANSI color codes
        $ColorCmdlet = "`e[96m" # bright cyan
        $ColorParam = "`e[93m" # yellow
        $ColorString = "`e[92m" # green
        $ColorVar = "`e[95m" # magenta
        $ColorNumber = "`e[94m" # blue
        $ColorComment = "`e[90m" # grey
        $Reset = "`e[0m"

        # Separate code and comment
        $parts = $Command -split '#', 2
        $code = $parts[0]
        $comment = if ($parts.Count -gt 1) { $parts[1] } else { $null }

        # Highlight: basic regex-based replacements
        $highlighted = $code `
            -replace '(\b[A-Za-z]+\-[A-Za-z]+\b)', "$ColorCmdlet`$1$Reset" ` # Cmdlets
        -replace '(\s-\w+)', "$ColorParam`$1$Reset" `   # Parameters
        -replace '("[^"]*"|''[^'']*'')', "$ColorString`$1$Reset" ` # Strings
        -replace '(\$[A-Za-z_]\w*)', "$ColorVar`$1$Reset" ` # Variables
        -replace '(\b\d+(\.\d+)?\b)', "$ColorNumber`$1$Reset" # Numbers

        # Print highlighted code
        Write-Host -NoNewline $highlighted

        # Print comment if present
        if ($comment) {
            Write-Host "$ColorComment# $comment$Reset"
        }
        else {
            Write-Host ""
        }
    }


    $lowerArgs = $Args | ForEach-Object { $_.ToLower() }
    if (($ShowHelp.IsPresent) -or ($lowerArgs.Contains('--help'))) {
        Show-Help
        return
    }
        
    if (($Version.IsPresent) -or ($lowerArgs.Contains('--version'))) {
        Show-Version
        return
    }

    # Separate filters and passdown args
    $filtersArgs = @()
    $passdownArgs = @()
    $foundDashDash = $false

    foreach ($a in $Args) {
        if (-not $foundDashDash -and $a -eq "--") {
            $foundDashDash = $true
            continue
        }
        if (-not $foundDashDash) {
            $filtersArgs += $a
        }
        else {
            $passdownArgs += $a
        }
    }
    if ($env:CMR_DEBUG) {
        Write-Host "Debug mode"
        Write-Host "used for filters $filtersArgs"
        Write-Host "Arguments passed down to selected target: $passdownArgs"
        return
    }


    $searchDirectory = "build"
    if (-not (Test-Path $searchDirectory)) {
        Write-Host "Error: no '$search_directory' folder found in this directory. Make sure to compile the project first." -ForegroundColor Red
        Write-Host "If you don't want to use the default build/ folder, just given another one as the first argument" -ForegroundColor Gray
    }

    $filter = $filtersArgs
    if ($filter.Count -ge 1 -and (Test-Path $filter[0] -PathType Container)) {
        $searchDirectory = $filter[0]
        $filter = $filter[1..($filter.Count - 1)]
    }

    if (-not (Test-Path $searchDirectory -PathType Container)) {
        Color red "Error: no '$searchDirectory' folder found in this directory."
        return
    }

    # List files excluding patterns
    $files = Get-ChildItem -Path $searchDirectory -Recurse -File | Where-Object { $_.FullName -notmatch '\.git|CMakeFiles|CMakeCache\.txt|Makefile|\.cmake|src|images|assets|_autogen' }

    # Apply filter via fzf if needed
    $filterEnabled = $false
    if ($filter.Count -gt 0) {
        $filterEnabled = $true
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            $files = ($files | ForEach-Object FullName | fzf --filter ($filter -join ' ') --no-sort) -split "`n"
        }
        else {
            $files = $files | Where-Object { $_.Name -like "*$($filter -join '*')*" }
        }
    }
    else {
        $files = $files.FullName
    }

    # Keep only executable files
    $execs = $files | Where-Object { (Get-Item $_).Attributes -notmatch 'Directory' -and (Get-Item $_).Extension -eq '' -or (Get-Item $_).Extension -eq '.exe' }

    $execsCount = $execs.Count
    if ($execsCount -eq 0) {
        if ($filterEnabled) {
            Write-Host "No target matched in list with filter '$($filter -join ' ')'." -ForegroundColor Red
        }
        else {
            Write-Host "No target found inside $searchDirectory/" -ForegroundColor Red
        }
    }
    elseif ($execsCount -eq 1) {
        $target = $execs[0]
        Write-Host blue "Running $target $($passdownArgs -join ' ')" -ForegroundColor Cyan
        & $target @passdownArgs
    }
    else {
        Write-Host "Multiple targets found, choose one" -ForegroundColor Magenta
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            $target = ($execs | fzf --height=100%)
        }
        else {
            for ($i = 0; $i -lt $execsCount; $i++) {
                Write-Host "$($i+1). $($execs[$i])"
            }
            $idx = Read-Host "Choose a target by index"
            if ($idx -match '^\d+$' -and $idx -ge 1 -and $idx -le $execsCount) {
                $target = $execs[$idx - 1]
            }
            else {
                Write-Host "Invalid number $idx" -ForegroundColor
                return
            }
        }
        if ($target) {
            Write-Host "Running $target $($passdownArgs -join ' ')" -ForegroundColor Cyan
            & $target @passdownArgs
        }
    }
}