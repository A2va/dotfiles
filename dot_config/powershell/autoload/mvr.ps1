function mvr {
    param(
        [string]$Filter
    )

    # Try to read the mainClass from pom.xml
    $targetClass = (Get-Content pom.xml | Select-String -Pattern 'mainClass' | ForEach-Object {
        ($_ -split '>')[1] -split '<'
    })[0]

    if (-not $targetClass) {
        # Get all .class files from target/, convert path separators to dots, and remove ".class"
        $files = fd --no-ignore -e class --base-directory target/ | ForEach-Object {
            $_ -replace '/', '.' -replace '\.class$', ''
        }

        $matched = $files
        if ($Filter) {
            $matched = $matched | Select-String -Pattern $Filter -SimpleMatch | ForEach-Object { $_.ToString() }
        }

        if (-not $matched -or $matched.Count -eq 0) {
            Write-Host "No match in detected files for filter $Filter in available classes:" -ForegroundColor Red
            $files | ForEach-Object { Write-Host $_ }
            return
        }
        elseif ($matched.Count -eq 1) {
            $targetClass = $matched[0]
        }
        else {
            # Use fzf to choose
            $targetClass = ($matched | fzf)
        }
    }

    Write-Host "Running $targetClass" -ForegroundColor Blue
    mvn -T 1C exec:java "-Dexec.mainClass=$targetClass"
}
