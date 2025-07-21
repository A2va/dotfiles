if test -f ~/.config/fish/internal.fish
    source ~/.config/fish/internal.fish &>/dev/null
end

# Functions

## Create a new folder and jump inside
function mk
    mkdir -p "$argv" && cd "$argv"
end

## Show information about Git identity
function gitid
    echo "Current identity is"
    echo "Email: $(git config user.email)"
    echo "Name: $(git config user.name)"
end

## Fix incorrect origin
function fixor
    if test "$argv[1]"
        git config remote.origin.url $argv[1]
    else
        echo "Current origin is " (color green (git config remote.origin.url))
        echo "To change it run " (color blue "fixor <new-origin-url>")
    end
end

# Aliases
alias l ls # just `ls`
alias ls eza # A better ls with colors
alias ll "ls -l"
alias la "ls -la"
alias rm 'rm -i'
alias mv 'mv -i'

alias x xmake
alias xr "xmake run"
alias xc "xmake clean"
alias xbr "xmake && xmake run"

alias gd gradle # just `gradle`
alias grr "gradle run" # Gradle Run
alias grb "gradle build" # Gradle Build
alias mvw "./mvnw" # call the maven wrapper (mvw instead of mvn)

alias ca cargo # just `cargo`
alias car "cargo run" # cargo run
alias cab "cargo build -q" # cargo build