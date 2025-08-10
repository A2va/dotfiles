
function r {

    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args,

        [Alias('w')]
        [switch]$Watch,

        [Alias('v')]
        [switch]$Version,

        [Alias('h', 'help')]
        [switch]$ShowHelp
    )

    $scriptVersion = "v20"
    $DEFINITION = "r $scriptVersion - Generic runner. Your play button in the terminal. Build+run almost anything"

    function Show-Help {
        Write-Host "`n$DEFINITION" -ForegroundColor Cyan
        Write-Host "Synopsis: [-v|-h|--help] | [filename] [sub program arguments]" -ForegroundColor Blue
        Write-Host "Tip: r.ps1 works great in pair with scr.ps1 !" -ForegroundColor Cyan
        Write-Host
        Write-Host "Run a given file" -ForegroundColor Green
        Show-PowerShellCommand "r hi.c --hello john # Run a C program with 2 arguments forwarded"
        Show-PowerShellCommand "r program.cpp # Run a C++, Rust, Java, Haskell, Python, Sage, Fish, Bash, or GMPL program with their compiler/interpreter"
        Show-PowerShellCommand "r somebin # If 'somefile' has a shebang or is an executable file, just run it"
        Show-PowerShellCommand "r App.kt # Run a main Kotlin class"
        
        Write-Host
        Write-Host "Guess the associated build tool depending on the context" -ForegroundColor Green
        Show-PowerShellCommand "r # Found a Cargo.toml ? cargo run. Found a pom.xml ? use mvr.fish (maven run)"
        Show-PowerShellCommand "r # Found a CMakeLists.txt ? use cmake + cmr. A Makefile present, but no target/ or build/ ? run 'cmr .'"
        Show-PowerShellCommand "r # Found a settings.gradle.kts/settings.gradle ? gradle run."

        Write-Host "Auto detect default files and run them" -ForegroundColor Green
        Show-PowerShellCommand "r # Found a main.cpp, main.c, App.java/Main.java (without Gradle or Maven files), compile and run them"
        Show-PowerShellCommand "r # Found a main.py -> use the python interpreter"

        Write-Host
        Write-Host "Enable debug mode via R_DEBUG variable to see what is planned to be run" -ForegroundColor Green
        Show-PowerShellCommand '$env:R_DEBUG=on; r # dump command for standard run'
    }

    function Show-Version {
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

    function Resolve-FileByContext {
        param([ref]$File)

        $lookup = @{
            "main.c"     = "basic C project"
            "main.cpp"   = "basic C++ project"
            "Main.java"  = "basic Java project"
            "App.java"   = "basic Java project"
            "main.py"    = "Python script"
            "Main.scala" = "Scala file"
        }

        foreach ($f in $lookup.Keys) {
            if (Test-Path $f) {
                $File.Value = $f
                return
            }
        }
    }

    function Get-MsvcRunCommand([string]$SourceFile, [string]$Output, [string]$LangFlag = "") {
        @"
`$installPath = &"$(${env:ProgramFiles(x86)})\Microsoft Visual Studio\Installer\vswhere.exe" -version 16.0 -property installationPath
Import-Module (Join-Path `$installPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")
Enter-VsDevShell -VsInstallPath `$installPath -SkipAutomaticLocation *> `$null
mkdir build 2>`$null
cl.exe $LangFlag /Fe:build\$Output.exe $SourceFile && build\$Output.exe
"@
    }

    function Detect-Project {
        param(
            [string[]]$Args,
            [switch]$Watch
        )

        $PassdownArgs = $Args
        $File = $null

        if ($Args.Count -gt 0 -and -not $Watch) {
            if (Test-Path $Args[0]) {
                $File = $Args[0]
                $PassdownArgs = $Args[1..($Args.Count - 1)]
            }
        }

        if (-not $File) {
            Resolve-FileByContext ([ref]$File)
        }

        $Ext = [System.IO.Path]::GetExtension($File).TrimStart('.')
        $Base = [System.IO.Path]::GetFileNameWithoutExtension($File)
        $Cmd = $null
        $WatchCmd = $null
        $WatchExts = @()
        $ExtraWatched = @()

        # --- Full Build System Detection ---
        if (Test-Path "Cargo.toml") {
            $Cmd = "cargo run"
            if (Get-Command cargo-watch -ErrorAction SilentlyContinue) {
                $WatchCmd = "cargo watch -c -x 'run __args__'"
            }
            else {
                $WatchExts = 'rs'
                $ExtraWatched += "Cargo.toml", "Cargo.lock"
            }
        }
        elseif (Test-Path "xmake.lua") {
            $Cmd = "xmake && xmake run"
            $WatchCmd = "xmake watch -q -c `"xmake; clear; xmake run __args__`""
        }
        elseif (Test-Path "CMakeLists.txt") {
            $Cmd = "cmake . -Bbuild && cmake --build build/ && cmr"
            $WatchExts = 'c', 'cpp', 'h', 'hpp', 'S'
            $ExtraWatched += "CMakeLists.txt"
        }
        elseif (Test-Path "Makefile") {
            if (Test-Path "target" -or Test-Path "build") {
                $Cmd = "make -j 8 && cmr"
            }
            else {
                $Cmd = "make -j 8 && cmr ."
            }
            $WatchExts = 'c', 'S', 'h'
            $ExtraWatched += "Makefile"
        }
        elseif (Test-Path "pom.xml") {
            $Cmd = "mvr"
            $WatchExts = 'java'
            $ExtraWatched += "pom.xml"
        }
        elseif ((Test-Path "gradlew") -or (Test-Path "settings.gradle.kts") -or (Test-Path "settings.gradle")) {
            $Cmd = "gradle --parallel run -q"
            $WatchCmd = "gradle --parallel run -t -q"
        }
        elseif (Test-Path "docker-compose.yml") {
            $Cmd = "docker compose up"
            $WatchCmd = "echo Error: docker compose watch mode is not supported"
        }
        elseif (Test-Path "gradle.properties") {
            if ((Get-Content "gradle.properties") -match "quarkus") {
                $Cmd = "quarkus dev"
                $WatchCmd = "echo Error: quarkus already reloads on changes"
            }
        }
        else {
            # Fall back to single file detection
            switch ($Ext) {
                'c' { $Cmd = Get-MsvcRunCommand $File $Base "/std:clatest"; $WatchExts = 'c' }
                'cpp' { $Cmd = Get-MsvcRunCommand $File $Base "/std:c++latest"; $WatchExts = 'cpp' }
                'rs' { $Cmd = "rustc $File -o build/$Base && .\build\$Base"; $WatchExts = 'rs' }
                'py' { $Cmd = "python $File"; $WatchExts = 'py' }
                'java' { $Cmd = "javac -d build $File && java -cp build $Base"; $WatchExts = 'java' }
                'kt' { $Cmd = "kotlinc $File -d build && kotlin -cp build $Base"; $WatchExts = 'kt' }
                'hs' { $Cmd = "ghc --run $File --" }
                'sh' { $Cmd = "bash $File" }
                'fish' { $Cmd = "fish $File"; $WatchExts = 'c', 'cpp', 'h' }
                'typ' { $Cmd = "typst compile $File"; $WatchCmd = "typst watch $File" }
                default {
                    if ($File -and (Test-Path $File -PathType Leaf -and (Get-Item $File).Attributes -match "Executable")) {
                        $Cmd = ".\$File"
                    }
                }
            }
        }

        return @{
            File         = $File
            Cmd          = $Cmd
            WatchCmd     = $WatchCmd
            WatchExts    = $WatchExts
            PassdownArgs = $PassdownArgs
            ExtraWatched = $ExtraWatched
        }
    }

    function Run-WatchMode($Info) {
        $Filter = @()
        foreach ($ext in $Info.WatchExts) {
            $Filter += "*.$ext"
        }
        $Files = Get-ChildItem -Recurse -Include $Filter | Select-Object -ExpandProperty FullName
        $Files += $Info.ExtraWatched

        if ($env:R_DEBUG) {
            Write-Host "Watch mode using files:" -ForegroundColor Blue
            $Files | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            Write-Host "Command: $($Info.Cmd) $($Info.PassdownArgs -join ' ')" -ForegroundColor Cyan
        }
        else {
            $CommandLine = "$($Info.Cmd) $($Info.PassdownArgs -join ' ')"
            while ($true) {
                $Before = Get-ChildItem -Recurse $Files | Get-FileHash
                & powershell -NoProfile -Command $CommandLine
                Start-Sleep -Seconds 1
                $After = Get-ChildItem -Recurse $Files | Get-FileHash
                if ($Before -ne $After) {
                    Clear-Host
                }
            }
        }
    }

    $lowerArgs = @()
    if ($null -ne $Args) {
        $lowerArgs = $Args | ForEach-Object { $_.ToLower() }
    }
    if (($ShowHelp.IsPresent) -or ($lowerArgs.Contains('--help'))) {
        Show-Help
        return
    }
    if (($Version.IsPresent) -or ($lowerArgs.Contains('--version'))) {
        Show-Version
        return
    }


    $Info = Detect-Project -Args $passThruArgs  -Watch:$Watch
    if (-not $Info.Cmd) {
        Write-Host "Could not detect project type or run target." -ForegroundColor Red
        return 1
    }

    if ($Watch) {
        Run-WatchMode -Info $Info
    }
    else {
        if ($env:R_DEBUG) {
            Write-Host "Would run: $($Info.Cmd) $($Info.PassdownArgs -join ' ')" -ForegroundColor Cyan
        }
        else {
            Invoke-Expression "$($Info.Cmd) $($Info.PassdownArgs -join ' ')"
        }
    }
}