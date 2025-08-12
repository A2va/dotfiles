# mvr - The missing "maven run" command you really want, working from the terminal
# Author: Samuel Roland
# Synopsis: mvr [class filter]
# Examples: mvr # 
#           mvr Gui # run the class matching "Gui" or prompt if several are matching
# License: MIT
# Notice: Copyright (c) 2024 Samuel Roland
# Source: https://codeberg.org/samuelroland/productivity/src/branch/main/HEIG/tools
#
# TODO: make it smarter before publishing
# TODO: make filter match exact class name, without considering package

function mvr

    set filter $argv[1]
    set target_class (cat pom.xml  | grep mainClass | cut --delimiter=">" --fields=2  | cut --delimiter="<" --fields=1)
    if test -z "$target_class"
        set files (string replace -a "/" "." (string replace -a ".class" "" (fd --no-ignore -e class --base-directory target/)))
        set matched $files
        if ! test -z "$filter"
            set matched (printf %s\n $files | grep -i $filter)
        end
        if test (count $matched) -eq 0
            color red "No match in detected files for filter $filter in available classes:"
            printf %s\n $files
            return
        else if test (count $matched) -eq 1
            set target_class $matched[1]
        else
            set target_class (printf %s\n $matched | fzf)
        end
    end
    color blue "Running $target_class"
    mvn -T 1C exec:java "-Dexec.mainClass=$target_class"
    # mvn -T 1C compiler:compile && java -cp target/classes "$target_class"
    # We could try to run it faster via this form, with paths to all useful jars separated by :,
    # but this would need to get a list of dependencies, to filter the list of given by
    # fd -e jar . ~/.m2/repository/ --no-ignore
    # to finally run something like this but with all deps in pom.xml, not this hard-coded version...
    # java -cp "$HOME/.m2/repository/com/formdev/flatlaf/3.5.1/flatlaf-3.5.1.jar:target/classes" ch/heig/sio/lab1/groupG/Gui
end
