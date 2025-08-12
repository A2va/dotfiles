def mvr [filter?: string] {
    # Try to read the mainClass from pom.xml
    let target_class = (open pom.xml
        | lines
        | where $it =~ 'mainClass'
        | str replace --regex '.*>(.*)<.*' '$1'
        | first
    )

    mut target_class = $target_class

    if ($target_class | is-empty) {
        # Find all .class files in target/ recursively
        let files = (glob "target/**/*.class"
            | path relative-to "target"
            | str replace --all "\\" "/"
            | str replace --all "/" "."
            | str replace --regex '\.class$' ''
        )

        mut matched = $files
        if $filter != null {
            $matched = ($files | where $it =~ $filter)
        }

        if ($matched | is-empty) {
            print -e $"(ansi red)No match in detected files for filter ($filter) in available classes:(ansi reset)"
            $files | each { print $in }
            return
        } else if ($matched | length) == 1 {
            $target_class = ($matched | first)
        } else {
            $target_class = ($matched | input list "Select a target to run:")
        }
    }

    print $"(ansi blue)Running ($target_class)(ansi reset)"
    mvn -T 1C exec:java $"-Dexec.mainClass=($target_class)"
}
