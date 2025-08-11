# CMake missing run command - find one target among one or many inside the build/ folder or a given folder
# Author: Samuel Roland
# It can actually be used even outside of a CMake project for any folder that produces one or several executable files
# License: MIT
# Notice: Copyright (c) 2024 Samuel Roland
# Source: https://codeberg.org/samuelroland/productivity/src/branch/main/HEIG/tools

set VERSION v5
set DEFINITION "cmr $VERSION - (c)make run - binary runner, the missing 'run' command for cmake, make, qb, ..."

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

function _show_help
    color cyan "$DEFINITION"
    color blue "Synopsis: cmr [-v|-h|--help] | [filter arguments] [--] [sub program arguments]"
    echo "How it works ?"
    echo "1. Find executable files under build/ or the folder given as first argument"
    echo "2. Then if there are arguments, they are used to filter this list"
    echo "2.5 If there are still multiple files, it will prompt to choose one via fzf"
    echo "3. Finally, if there are arguments after a '--' argument it will be forwarded to the chosen target"
    echo
    color green "Simple execution with a single binary file under build/hello"
    show_fish_command "cmr # just runs ./build/hello"
    show_fish_command "cmr -- --name john # just forward arguments after -- and runs ./build/hello --name john"

    echo
    color green "Multiple binary files under a different folder target/ -> target/hello_1 and target/hello_2 and target/goodbye2morrow"
    show_fish_command "cmr target/ # just search under ./target, it will prompt the 3 files via fzf"
    show_fish_command "cmr target/ h 2 # just search under ./target and filter the list with fuzzy matching 'h 2' -> it will run ./target/hello_2"
    show_fish_command "cmr target/ hello 2 # just search under ./target and filter the list with fuzzy matching 'hello 2' -> it will run ./target/hello_2"
    show_fish_command "cmr target/ hello 2 -- --msg byebye # same with 2 arguments forwarded -> it will run ./target/hello_2 --msg byebye"

    echo
    color green "Enable debug mode via CMR_DEBUG variable"
    show_fish_command "CMR_DEBUG=on cmr target/ hello 2 -- --msg byebye -- # WIP: only arguments separation dump"
end

function cmr
    if [ "$argv[1]" = -v ]
        echo "Fish function $VERSION installed."
        return
    end

    if [ "$argv[1]" = --help ]
        _show_help
        return
    end
    if [ "$argv[1]" = -h ]
        _show_help
        return
    end

    # Separate arguments before and after --
    set filters_args
    set passdown_args
    set found_dashdash 0

    for a in $argv
        if [ "$a" = -- ] && [ $found_dashdash -eq 0 ] # make sure only the first -- is considered
            set found_dashdash 1
            continue
        end
        if test $found_dashdash -eq 0
            set -a filters_args $a
        else
            set -a passdown_args $a
        end
    end

    if set -q CMR_DEBUG
        echo WIP debug mode # todo continue with filtering and more infos if needed ??
        echo Arguments used for filters: $filters_args
        echo Arguments passed down to selected target: $passdown_args
        return
    end

    set search_directory build/
    if ! test -d $search_directory # Verify the presence of the searched directory
        color red "Error: no '$search_directory' folder found in this directory. Make sure to compile the project first."
        color grey "If you don't want to use the default build/ folder, just given another one as the first argument"
        return
    end

    set filter $filters_args # the filter is by default starts at arg 1
    if test -d $filter[1] # Maybe a directory was given instead of build
        set search_directory $filter[1]
        set filter $filter[2..] # it can be the starts at arg 2 in case the first is a directory
    end

    if ! test -d $search_directory # Verify the presence of the searched directory
        color red "Error: no '$search_directory' folder found in this directory. Make sure $search_directory actually exists."
        return
    end

    # List files inside build/ and remove known patterns
    # .git contains executable files ... like .git/hooks/applypatch-msg.sample
    set files (find $search_directory -type f | grep -vP "\.git|CMakeFiles|CMakeCache.txt|Makefile|.*\.cmake|src|images|assets|.*_autogen")

    # Filter the list with first argument
    set filter_enabled 0
    if ! test -z "$filter"
        set filter_enabled 1
        set files (printf %s\n $files | fzf --filter "$filter" --no-sort)
    end

    # Filter the list to only take executable files (those who have the 'x' file permission)
    set execs
    for f in $files
        if test -x $f
            set -a execs $f
        end
    end

    # Depending on how much execs, we will stop, run it or ask which target to run
    set execs_count (count $execs)
    if test $execs_count -eq 0
        if test $filter_enabled -eq 1
            color red "No target matched in list with filter '$filter', try another filter or without any filter."
        else
            color red "No target found inside $search_directory/ :( If the target actually exists, run it manually like ./$search_directory/target_name"
        end
    else if test $execs_count -eq 1
        set target "$execs[1]"
        color blue "Running $target $passdown_args"
        $target $passdown_args # we are confident the file exists because we "find" it just before
    else
        color magenta "Multiple targets found, choose one or run again with a filter with any number of argument"
        # Ask via fzf if available
        if command -q -v fzf # if fzf is found
            set target (printf %s\n $execs | fzf --height=~100%)
        else
            for i in (seq (count $execs))
                echo $i. $execs[$i]
            end
            read -P "Choose a target by index: " idx

            # Make sure 1 <= $idx <= count($execs)
            if test (count $execs) -ge "$idx" -a 0 -lt $idx
                set target $execs[$idx]
            else
                color red "Invalid number $idx"
                return
            end
        end
        if ! test -z "$target"
            color blue "Running $target $passdown_args"
            $target $passdown_args
        end
    end
end
