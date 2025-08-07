module utils {
    export const VERSION = "v20"
    export def color_print [color: string, msg: string] {
        print ($"(ansi $color)($msg)(ansi reset)")
    }

    export def show_nu_command [cmd: string]: nothing -> string {
        let parts = ($cmd | split row '#' | each {|x| $x | str trim })
        if ($parts | length) == 1 {
            print ($parts | get 0)
        } else {
            print ($"(ansi green)($parts.0)(ansi reset) (ansi light_gray)# ($parts.1)(ansi reset)")
        }
    }

    export def format_watch_cmd [cmd: string, args: list<string>] {
        let joined = $args | str join ' '
        if ($cmd | str contains '__args__') {
            $cmd | str replace -a '__args__' $joined
        } else {
            $cmd ++ ' ' ++ $joined
        }
    }
}
use utils *

# r v20 - Generic runner. Your play button in the terminal. Build+run almost anything, watch mode included 🔥
# Tip: r.nu works great in pair with scr.nu !"
# Run a given file
#   `r hi.c --hello john` - Run a C program with 2 arguments forwarded
#   `r somefile` - If 'somefile' has a shebang or is an executable file, just run it
# Guess the associated build tool depending on the context
#   `r` - Found a Cargo.toml ? cargo run. Found a pom.xml ? use mvr.fish (maven run)`
#   `r` - Found a CMakeLists.txt ? use cmake + cmr. A Makefile present, but no target/ or build/ ? run 'cmr .'
#   `r` - Found a settings.gradle.kts/settings.gradle ? gradle run.
# Auto detect default files and run them
#   `r` - Found a main.cpp, main.c, App.java/Main.java (without Gradle or Maven files), compile and run them
#   `r` - Found a main.py -> use the python interpreter
# Run anything supported above in WATCH MODE 🔥🔥🔥, via generic or native watcher
#   `r -w main.c --hello john` - will build and run main.c
def r [
  ...args: string
  --watch(-w)             # Enable watch mode
  --version(-v)            # Show version
] {
    if $version {
        print $"Nushell command ($VERSION) installed."
        return
    }

    # Auto-detect file
	let file = if not ($args | is-empty) { $args.0 }
	let file_exists = if $file != null { $file | path exists } else { false }

	let passdown_args = if $file_exists {
		$args | skip 1
	} else {
		$args
	}

    let file_to_run = if $file != null {
        $file
    } else {
        let default_files = [
            # [name, guard_closure]
            [ 'main.c', { not (['CMakeLists.txt', 'xmake.lua', 'Makefile'] | any {|f| $f | path exists }) } ],
            [ 'main.cpp', { not (['CMakeLists.txt', 'xmake.lua', 'Makefile'] | any {|f| $f | path exists }) } ],
            [ 'Main.java', { not (['pom.xml', 'settings.gradle.kts', 'settings.gradle'] | any {|f| $f | path exists }) } ],
            [ 'App.java', { not (['pom.xml', 'settings.gradle.kts', 'settings.gradle'] | any {|f| $f | path exists }) } ],
            [ 'main.py', { true } ],
            [ 'Main.scala', { true } ],
        ]

        # Get the name from the [name, guard] list
        try {
            ($default_files | where {|item| (do $item.1) and ($item.0 | path exists) } | first).0
        } catch {
            null
        }
    }

    let file_exists = if $file_to_run != null { $file_to_run | path exists } else { false }

    let runner_info = do {
        let single_file_info = if $file_exists {
            let file = $file_to_run
            let ext = ($file | path parse).extension?
            let base = ($file | path basename | str replace $".($ext)" "")

            let cl_compile_script = {|file: string, base: string, flags: string|
                # Get VS install path
                let prog_files_x86 = $env.'ProgramFiles(x86)'
                let ps_command = $"&'($prog_files_x86)\\Microsoft Visual Studio\\Installer\\vswhere.exe' -version 16.0 -property installationPath"
                let install_path = (powershell -NoProfile -Command $ps_command | str trim)

                let script = ([
                    $"  Import-Module \"($install_path)\\Common7\\Tools\\Microsoft.VisualStudio.DevShell.dll\";",
                    $"  Enter-VsDevShell -VsInstallPath \"($install_path)\" -SkipAutomaticLocation *> $null;",
                    "  mkdir build 2>$null;",
                    $"  cl.exe ($flags) /Fe:build\\($base).exe ($file);"
                ] | str join "; ")

                $script
            }

            match $ext {
                'rs' => { cmd: $"rustc ($file) -o build/($base) and build/($base)", watch_exts: ['rs'] }
                # 'cpp' => { cmd: $"g++ -std=c++2a -o build/($base) ($file) and ./build/($base)", watch_exts: ['cpp', 'h' 'hpp'] }
                # 'c' => { cmd: $"gcc -o build/($base) ($file) and ./build/($base)", watch_exts: ['c', 'h'] }
                'cpp' => {
                    let script = do $cl_compile_script $file $base "/std:c++latest"
                    # Build here because inlining the ps cmd with nu is not possible
                    powershell -NoProfile -Command $script
                    {cmd: $"./build/($base)", watch_exts: ['cpp', 'cxx', 'h', 'hpp'], ps_cl_cmd: $script}
                }
                'c' => {
                    let script = do $cl_compile_script $file $base "/std:clatest"
                    # Build here because inlining the ps cmd with nu is not possible
                    powershell -NoProfile -Command $script
                    {cmd: $"./build/($base)", watch_exts: ['c', 'h'], ps_cl_cmd: $script}
                }
                'java' => {
                    let javac = (which javac | get 0.name)
                    let java = (which java | get 0.name)
                    { cmd: $"($javac) -d build ($file) and ($java) -classpath build ($base)", watch_exts: ['java'] }
                }
                'py' => { cmd: $"python ($file)", watch_exts: ['py'] }
                'sage' => { cmd: $"sage ($file)", watch_exts: ['sage'] }
                'kt' => { cmd: $"kotlinc -d build ($file) and kotlin -classpath build ($base)", watch_exts: ['kt'] }
                'hs' => { cmd: $"ghc --run ($file) --", watch_exts: ['hs'] }
                'fish' => { cmd: $"fish ($file)", watch_exts: ['fish'], extra_watched_files: [$file] }
                'sh' => { cmd: $"sh ($file)", watch_exts: ['sh'] }
                'sc' | 'scala' => { cmd: $"scala-cli run -q ($file)", watch_cmd: $"scala-cli run -q -w ($file)", watch_exts: ['scala', 'sc'] }
                'yml' => { cmd: $"ansible-playbook ($file) -K -v", watch_exts: ['yml'] }
                'typ' => { cmd: $"typst compile ($file)", watch_cmd: $"typst watch ($file)", watch_exts: ['typ'] }
                _ => {
                    let first_line = (open --raw $file | lines | get 0?)
                    if ($first_line != null) and ($first_line | str starts-with "#!") {
                        chmod +x $file
                    }

                    let format_file = {|$file| 
                        if ($file | str starts-with '/') { $file } else { $"./($file)" }
                    }

                    # On linux we can check the executable flag
                    let c  = if ($nu.os-info.name == "linux") and ($file | path exists) and (ls $file | get 0.mode | str contains 'x')  {
                        do $format_file
                    } else if($nu.os-info.name == "windows") {
                        # it will error if that that's not an exe
                        do $format_file
                    }
                    {cmd: $c}
                }
            }
        }

        if $single_file_info != null {
            $single_file_info
        } else if ('xmake.lua' | path exists) {
            { cmd: 'xmake and xmake run', watch_cmd: 'xmake watch -q -c "xmake; clear; xmake run __args__"' }
        } else if ('Cargo.toml' | path exists) {
            if (which cargo-watch | is-empty) {
                { cmd: 'cargo run', watch_exts: ['rs'], extra_watched_files: ['Cargo.toml', 'Cargo.lock'] }
            } else {
                { cmd: 'cargo run', watch_cmd: "cargo watch -c -x 'run __args__'" }
            }
        } else if ('CMakeLists.txt' | path exists) {
            if (which cmr | is-empty) {
                color_print red "Missing cmr command"
                return 1
            }
            { cmd: 'cmake . -Bbuild and cmake --build build/ -j 8 and clear and cmr', watch_exts: ['c', 'cpp', 'h', 'hpp', 'S'], extra_watched_files: ['CMakeLists.txt'] }
        } else if ('Makefile' | path exists) {
            if (which cmr | is-empty) {
                color_print red "Missing cmr command"
                return 1
            }
            let has_build_folder = ('build' | path exists) or ('target' | path exists)
            let run_cmd = if $has_build_folder { 'cmr' } else { 'cmr .' }
            { cmd: $"make -j 8 and ($run_cmd)", watch_exts: ['c', 'h', 'S'], extra_watched_files: ['Makefile'] }
        } else if ('pom.xml' | path exists) {
            { cmd: 'mvr', watch_exts: ['java'], extra_watched_files: ['pom.xml'] }
        } else if (['settings.gradle.kts', 'settings.gradle'] | any {|f| $f | path exists }) {
            { cmd: 'gradle --parallel run -q', watch_cmd: 'gradle --parallel run -t -q' }
        } else if ('docker-compose.yml' | path exists) {
            { cmd: 'docker compose up', watch_cmd: 'echo Docker Compose watch mode unsupported' }
        }
    }

    # At this point, not having any command means we really didn't detected anything supported
    if $runner_info == null  {
        color_print red "Sorry, but r.nu failed to match any supported project type in this folder."
        color_print grey "You can show the help with r -h or r --help to see what's supported"
        color_print grey "Maybe that's a bug, please make sure you are using the latest version or report the bug !"
        return 2
    }

    let cmd = $runner_info.cmd
    let ps_cl_cmd = $runner_info.ps_cl_cmd
    let watch_cmd = $runner_info.watch_cmd? | default ""
    let watch_exts = $runner_info.watch_exts? | default []
    let extra_watched_files = $runner_info.extra_watched_files? | default []


    #  Execute or watch
    if $watch {
        if $watch_cmd != "" {
            color_print blue 'Running in native watch mode'
            let final_cmd = format_watch_cmd $watch_cmd $passdown_args

            if $env.R_DEBUG? == 'on' {
                show_nu_command $final_cmd
            } else {
                nu -c $final_cmd
            }
        } else {
            color_print blue 'Running in watch mode'
            let joined_cmd = $"($cmd) ($passdown_args | str join ' ')"

            if $env.R_DEBUG? == 'on' {
                print "Watching files:"
                $watch_exts | each {|e| print $" - *.( $e )" }
                $extra_watched_files | each {|f| print $" - ($f)" }
                print $"Will run: nu -c '($joined_cmd)' on matching changes"
            } else {
                watch . { |op, path, new_path| 
                    let ext = ($path | path parse).extension?

                    if (($ext != null and ($watch_exts | any {|e| $e == $ext })) or
                        ($extra_watched_files | any {|f| $f == $path })) {
                        if ps_cl_cmd != null {
                            powershell -NoProfile -Command $ps_cl_cmd
                        }
                        nu -c $joined_cmd
                    }
                }
            }
        }
    } else {
        color_print blue $"Running: ($cmd)"
        let final_cmd = $"($cmd) ($passdown_args | str join ' ')"

        if $env.R_DEBUG? == 'on' {
            show_nu_command $final_cmd
        } else {
            nu -c $final_cmd
        }
    } 
}
