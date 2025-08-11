module utils {
    export const VERSION = "v5"
    export def color_print [color: string, msg: string] {
        print ($"(ansi $color)($msg)(ansi reset)")
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

# A cmake run command.
# How it works ?
#   1. Find executable files under build/ or the folder given as first argument
#   2. Then if there are arguments, they are used to filter this list
#   2.5 If there are still multiple files, it will prompt to choose one
#   3. Finally, if there are arguments after a '--' argument it will be forwarded to the chosen target
# 
# Simple execution with a single binary file under build/hello
#   - `cmr # just runs ./build/hello`
#   - `cmr -- --name john # just forward arguments after -- and runs ./build/hello --name john`
# Multiple binary files under a different folder target/ -> target/hello_1 and target/hello_2 and target/goodbye2morrow
#   - `cmr target/ # just search under ./target, it will prompt the 3 files`
#   - `cmr target/ h 2 # just search under ./target and filter the list with fuzzy matching 'h 2' -> it will run ./target/hello_2``
#   - `cmr target/ hello 2 # just search under ./target and filter the list with fuzzy matching 'hello 2' -> it will run ./target/hello_2`
#   - `cmr target/ hello 2 -- --msg byebye # same with 2 arguments forwarded -> it will run ./target/hello_2 --msg byebye`
# Enable debug mode via CMR_DEBUG variable
#   - `CMR_DEBUG=on cmr target/ hello 2 -- --msg byebye -- # WIP: only arguments separation dump`
def cmr [
    ...args: string
    --version(-v) 
] {
    if $version {
        print $"Nushell command ($VERSION) installed."
        return
    }

    # Split before/after --
    mut filters_args = []
    mut passdown_args = []
    mut found_dashdash = false

    for a in $args {
        if (not $found_dashdash) and ($a == "--") {
            $found_dashdash = true
            continue
        }
        if (not $found_dashdash) {
            $filters_args = ($filters_args | append $a)
        } else {
            $passdown_args = ($passdown_args | append $a)
        }
    }

    if ($env | get --ignore-errors CMR_DEBUG | is-not-empty) {
        print "WIP debug mode"
        print $"Arguments used for filters: ($filters_args)"
        print $"Arguments passed down to selected target: ($passdown_args)"
        return
    }

    mut search_directory = "build"
    if not ($search_directory | path exists) {
        color_print red $"Error: no '($search_directory)' folder found."
        color_print grey "If you don't want to use build/, pass another folder as the first argument"
        return
    }

    mut filter = $filters_args
    if ($filter | length) > 0 and ($filter | get 0 | path type) == "dir" {
        $search_directory = ($filter | get 0)
        $filter = ($filter | skip 1)
    }

    if not ($search_directory | path exists) {
        color_print red $"Error: no '($search_directory)' folder found."
        return
    }

    # List files, exclude unwanted patterns
    mut files = (glob $"($search_directory)/**/*"
    | where { ($in | path type) == "file" }
    | where { $in !~ '\.git|CMakeFiles|CMakeCache\.txt|Makefile|\.cmake|src|images|assets|_autogen' })

    # Apply filter if present
    let filter_enabled = ($filter | length) > 0
    if $filter_enabled {
        let filter_str = ($filter | str join " ")
        $files = ($files | where name =~ $filter_str)
    }

    # Keep only executable files (UNIX: +x perms or Windows: .exe)
    let execs = ($files | where { 
        ($in.name | str ends-with ".exe") or (($in.perms? | str contains "x") and not ($in.name | str ends-with ".cmake"))
    } | get name)

    let execs_count = ($execs | length)
    if $execs_count == 0 {
        if $filter_enabled {
            color red $"No target matched with filter '($filter | str join " ")'."
        } else {
            color red $"No target found inside ($search_directory)/"
        }
        return
    } else if $execs_count == 1 {
        let target = ($execs | get 0)
        color blue $"Running ($target) ($passdown_args | str join " ")"
        ^$target ...$passdown_args
    } else {
        color magenta "Multiple targets found, choose one:"
        let target = $execs | input list "Select a target to run:"
        if ($target | is-empty) {
            color red "No selection."
            return
        }
        color blue $"Running ($target) ($passdown_args | str join " ")"
        ^$target ...$passdown_args
    }
}