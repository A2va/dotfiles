# r - Generic runner. Your play button in the terminal. Build+run almost anything, watch mode included.
# Supported options: just see the help, there are too many to list here
# Author: Samuel Roland
# License: MIT
# Notice: Copyright (c) 2024 Samuel Roland
# Source: https://codeberg.org/samuelroland/productivity/src/branch/main/HEIG/tools
#
# Take inspiration from
# https://github.com/paldepind/projectdo

set VERSION v20
set DEFINITION "r $VERSION - Generic runner. Your play button in the terminal. Build+run almost anything, watch mode included 🔥"

# Easy printing of colored text, use -d for diminued mode
function color
    set args $argv && if [ "$argv[1]" = -d ]
        set_color -d
        set args $argv[2..]
    end && set_color $args[1] && echo $args[2..] && set_color normal
end

# Show a Fish command with code highlighting, and comment in grey
function show_fish_command
    set parts (string split "#" "$argv")
    echo -n (string trim (echo -n $parts[1] | fish_indent --ansi))
    test (count $parts) -gt 1 && set comment (string trim $parts[2]) && color -d grey "# $comment" || echo
end

# Routing fd or fdfind
function somefd
    if command -v fd >/dev/null
        fd --no-ignore-vcs $argv
    else if command -v fdfind >/dev/null
        fdfind --no-ignore-vcs $argv
    else
        color red "fd or fdfind was not found, please install it"
        show_fish_command "sudo dnf install fd-find"
        show_fish_command "sudo apt install fd-find"
        return 2
    end
end

function show_help
    color cyan "$DEFINITION"
    color blue "Synopsis: r [-v|-h|--help] | [-w] [filename] [sub program arguments]"
    color blue "Tip: r.fish works great in pair with scr.fish !"
    echo
    color green "Run a given file"
    show_fish_command "r hi.c --hello john # Run a C program with 2 arguments forwarded"
    show_fish_command "r program.cpp # Run a C++, Rust, Java, Haskell, Python, Sage, Fish, Bash, or GMPL program with their compiler/interpreter"
    show_fish_command "r setup.yml # Probably an Ansible playbook, just with ansible-playbook"
    show_fish_command "r somebin # If 'somefile' has a shebang or is an executable file, just run it"
    show_fish_command "r App.kt # Run a main Kotlin class"

    echo
    color green "Guess the associated build tool depending on the context"
    color -d grey "It also can ask to choose a target in case there are several ones"
    show_fish_command "r # Found a Cargo.toml ? cargo run. Found a pom.xml ? use mvr.fish (maven run)"
    show_fish_command "r # Found a CMakeLists.txt ? use cmake + cmr. A Makefile present, but no target/ or build/ ? run 'cmr .'"
    show_fish_command "r # Found a settings.gradle.kts/settings.gradle ? gradle run. Found a playbook.yml ? -> run with ansible-playbook"

    echo
    color green "Auto detect default files and run them"
    show_fish_command "r # Found a main.cpp, main.c, App.java/Main.java (without Gradle or Maven files), compile and run them"
    show_fish_command "r # Found a main.py -> use the python interpreter"

    echo
    color green "Run anything supported above in WATCH MODE 🔥🔥🔥, via generic or native watcher"
    show_fish_command "r -w main.c --hello john # will build and run main.c everytime you save .c files, with 2 forwarded arguments"
    show_fish_command "r -w hello # CMakeLists.txt detected -> it will build and run everytime you save .c, .cpp, .h, and .hpp files and forward 'hello' argument to cmr filter"
    show_fish_command "r -w # Cargo project detected + cargo-watch installed -> it will just use 'cargo watch' as native watcher"
    show_fish_command "r -w # Cargo project detected + without cargo-watch -> it will run 'cargo run' everytime you save any .rs file"

    echo
    color green "Enable debug mode via R_DEBUG variable to see what is planned to be run"
    show_fish_command "R_DEBUG=on r # dump command for standard run"
    show_fish_command "R_DEBUG=on r -w # dump command for watched run"
end

function r
    if [ "$argv[1]" = -v ]
        echo "Fish function $VERSION installed."
        return
    end
    if test "$argv[1]" = --help || test "$argv[1]" = -h
        show_help && return
    end

    # Show a script step in color
    function step
        color green ">>> $argv"
    end

    # To be determined by the context
    set cmd # this must be defined as the command as an array of string, the $passdown_args will be appended at the end of this command
    set watch_exts # file extensions to watch, to leave empty if we don't know or if there is a native watch support
    set watch_cmd # if there is native watch support, this command must be defined (ex. gradle run -> gradle run -t), entr will not be used
    set extra_watched_files # specific files to watch in addition to filter given by watch_exts
    # todo do we need a way to specify only_watched_files ??

    # By default, running r in a project -> all args should be passed down
    set passdown_args $argv

    # Skip the -w
    if test "$argv[1]" = -w
        set passdown_args $passdown_args[2..]
    end

    # Extraction of file as first argument
    set file $passdown_args[1]
    set detected ""

    # Contextual preparation - mostly based on templates generated by scr
    if ! test -f "$file"
        # C and C++ - only take the main if there is no CMake setup
        if ! test -f "CMakeLists.txt"
            if ! test -f "xmake.lua"
                if ! test -f Makefile
                    if test -f "main.c"
                        set file main.c
                        set single_file_detection 1
                        set detected "basic C project"
                    end
                    if test -f "main.cpp"
                        set file main.cpp
                        set single_file_detection 1
                        set detected "basic C++ project"
                    end
                end
            end
        end
        # Java with Main.java or App.java
        if ! test -f "pom.xml" -o -f "settings.gradle.kts" -o -f "settings.gradle"
            if test -f "Main.java"
                set file Main.java
                set single_file_detection 1
                set detected "basic Java project"
            end
            if test -f "App.java"
                set file App.java
                set single_file_detection 1
                set detected "basic Java project"
            end
        end

        if ! test -f "$file"
            if test -f "playbook.yml"
                set file "playbook.yml"
                set detected "Ansible playbook"
            end
        end
        if ! test -f "$file"
            if test -f "main.py"
                set file "main.py"
                set detected "Python script"
            end
        end
        if ! test -f "$file"
            if test -f "Main.scala"
                set file "Main.scala"
                set detected "Scala file"
            end
        end
    end


    # If we have an existing file, let's try to compile it and run it
    if test -f "$file"
        set -l ext (string split "." $file)[-1] # section after last point
        set -l base (basename -s ".$ext" $file)

        # If the first arg is a filename, we have to remove it in the passed down args
        if ! set -q single_file_detection
            set passdown_args $passdown_args[2..]
        end

        switch "$ext"
            case rs # Rust
                set cmd rustc $file -o "build/$base" \&\& build/$base
            case cpp
                set cmd g++ -std=c++2a -o "build/$base" "$file" \&\& "./build/$base"
            case c
                set cmd gcc -o "build/$base" "$file" \&\& "./build/$base"
            case java
                # make sure we are using the same jdk in case there are multiple installation with different versions (openjdk from dnf + sdkman)
                set javac_path (command -s javac)
                set java_path (path dirname $javac_path)"/java"
                set cmd $javac_path -d build "$file" \&\& $java_path -classpath build "$base"
            case py # Python
                set cmd python $file
            case sage # sagemath
                set cmd sage $file
            case kt # Kotlin
                set cmd "kotlinc -d build \"$file\" ; set finalClass (basename -s .class (ls build/ | grep -i (basename -s .kt $file))) >/dev/null; kotlin -classpath build \"\$finalClass\""
            case hs # Haskell
                set cmd ghc --run $file --
            case fish # fish scripts
                set cmd fish $file
                set watch_exts c cpp h
                set extra_watched_files $file
            case sh # shell script
                set cmd sh $file
            case sc scala # Scala file
                set cmd scala-cli run -q $file
                set watch_cmd scala-cli run -q -w $file
            case yml # Ansible playbook in YAML
                set cmd ansible-playbook $file -K -v
            case typ # Typst compilation or watch
                set cmd typst compile $file
                set watch_cmd typst watch $file
            case lp # GLPK with LP format
                set cmd glpsol --lp $file
            case mod # GLPK with GMPL format
                set cmd glpsol -m $file
            case '*'
                # Check if the file contains a shebang (starts with the name of the interpreter: #!/bin/python i.e.)
                # Checking inside a binary file is not an issue I guess
                if head $file -n 1 | grep -P "#!/.*(/.*)+" >/dev/null
                    chmod +x $file
                end

                # If the file is a simple executable, just run it
                if test -x $file
                    set callpath $file
                    if ! string match -r "^/" $file &>/dev/null
                        set callpath ./$file
                    end
                    step "Running executable: $callpath $passdown_args"
                    set cmd $callpath
                end
        end

        mkdir -p build # todo: do not insert if not used

        # This extension has been recognized, we know we have to watch it
        # we could watch $file via extra_watched_files but we would miss files that are supported
        # (like Java class where javac can do the job of builded imported files)
        if test -z "$watch_exts"
            set watch_exts $ext
        end
    else # otherwise this might be a bigger project, let's try to guess it

        # Xmake
        if test -f "xmake.lua"
            set cmd xmake \&\& xmake run
            set watch_cmd xmake watch -q -c '"xmake; clear; xmake run __args__"'
            # todo fix the double double quotes need ??
            # instead of xmake watch -r to run in addition to build, we run it ourself to be able to clean in the middle
            set detected "Xmake project"
        end

        # Cargo
        if test -f "Cargo.toml"
            set cmd cargo run
            # If we have cargo watch plugin, let's use that !
            if command -v cargo-watch >/dev/null
                set watch_cmd cargo watch -c -x "'run __args__'"
            else
                set watch_exts rs
                set extra_watched_files Cargo.toml Cargo.lock
            end
            set detected "Cargo project"
        end

        # CMake
        if test -f "CMakeLists.txt"
            set watch_exts c cpp h hpp S
            set extra_watched_files CMakeLists.txt
            if ! type -q cmr
                color red "Looks like you don't have cmr.fish installed ? Make sure to install the latest version to run that."
                return
            end
            set cmd cmake . -Bbuild \&\& cmake --build build/ -j 8 \&\& clear \&\& cmr
        end

        # Note: this is designed for the ASM course mostly !
        # If we have a Makefile we have to compile and run via cmr
        # Cmr must be run in the current folder if no target/ or build/ folder where generated
        if test -f Makefile
            if ! type -q cmr
                color red "Looks like you don't have cmr.fish installed ? Make sure to install the latest version to run that."
                return
            end
            if test (count $passdown_args) -eq 0
                step "Building via 'make' and running via 'cmr'"
            else
                step "Building via 'make' and running via 'cmr' with arguments '$passdown_args'"
            end
            # todo : should we switch to make -s ? how to show building with make in watch mode to make "make" call visible ??
            if test ! -d target/ -a ! -d build/
                set cmd make -j 8 \&\& cmr . # notice the . to use the current folder and not the build folder for research !
            else
                set cmd make -j 8 \&\& cmr
            end
            set watch_exts c S h # todo fix watching for ASM lab 1 exo 4 opti and debug, it doesnt work...
            # this requires more thinking and documentation as r -w exo1 will match the executable exo1 instead of the Makefile project...
            set extra_watched_files Makefile
        end

        # Maven run - custom fish function
        if test -f "pom.xml"
            set cmd mvr
            set watch_exts java
            set extra_watched_files pom.xml
        end

        # todo support sc.fish wrapper of sbt
        # native watch mode
        # https://www.scala-sbt.org/1.x/docs/Triggered-Execution.html

        if ! string match "$PWD" "$HOME" &>/dev/null
            # Try to detect Quarkus even before it generates a ".quarkus" folder after first compilation
            if test -f gradle.properties
                if cat gradle.properties | grep quarkus &>/dev/null
                    set cmd quarkus dev
                    set watch_cmd echo Error: quarkus watch mode is not supported as probably too slow and it already do class hot reloading...
                end
            end

            # Gradle
            if test -f "settings.gradle.kts" -o -f "settings.gradle"
                set cmd gradle --parallel run -q
                set watch_cmd gradle --parallel run -t -q
            end
        end

        # Docker compose
        if test -f "docker-compose.yml"
            set cmd docker compose up
            set watch_cmd echo Error: docker compose watch mode is not supported as it is probably too slow
        end
    end

    # At this point, not having any command means we really didn't detected anything supported
    if test -z "$cmd"
        color red "Sorry, but r.fish failed to match any supported project type in this folder"
        color grey "You can show the help with r -h or r --help to see what's supported"
        color grey "Maybe that's a bug, please make sure you are using the latest version or report the bug !"
        # todo: an easy way to report the bug ?? maybe via lxup report or something like that ?
        return 2
    end

    # TODO: manage the edge case of watch_cmd is defined + watch_exts is defined -> use entr but with watch_cmd
    # Run in watch mode or not, using native watch or just entr generic watcher
    ## Now that watch_cmd, cmd and watch_exts are set, we can finally run it
    if test "$argv[1]" = -w
        # Build -e list for fd
        set filter_cmd somefd
        for a in $watch_exts
            set -a filter_cmd -e $a
        end

        if test -n "$watch_cmd"
            color blue "Running in native watch mode"

            # Replace __args__ in given watch_cmd to inject arguments when it is just not appended at the end
            set final_cmd $watch_cmd $passdown_args
            if string match --regex __args__ "$watch_cmd" >/dev/null
                set final_cmd (string replace -a -- __args__ "$passdown_args" "$watch_cmd") # -- are important to forward argument that contains short flags like "-q server"
            end

            if set -q R_DEBUG
                show_fish_command $final_cmd
            else
                fish -c "$final_cmd"
            end
        else
            color blue "Running in watch mode"

            set entr_cmd entr -c -c -r fish -ic
            if set -q R_DEBUG
                echo r.fish decided on files to watch with selector
                show_fish_command $filter_cmd
                echo with additional watched files: $extra_watched_files
                echo watcher via given entr command
                show_fish_command $entr_cmd
                echo where `cmd` is
                show_fish_command $cmd $passdown_args
            else
                begin
                    $filter_cmd
                    printf %s\n $extra_watched_files
                end | $entr_cmd "$cmd $passdown_args" # -i is important to make sure the configuration fully read in interactive mode !
            end
        end
    else
        color blue "Running $cmd, use -w to enable watch mode"
        if set -q R_DEBUG
            echo r.fish would run this command
            show_fish_command $cmd $passdown_args
        else
            fish -ic "$cmd $passdown_args"
        end
    end
end
