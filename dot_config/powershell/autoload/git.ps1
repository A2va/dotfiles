# Smart `git`: only `git clone` is intercepted, everything else goes straight
# to git.exe. The clone logic lives in ~/.local/bin/wrappers/git-clone.ps1.
function global:git {
    if ($args.Count -gt 0 -and [string]$args[0] -eq 'clone') {
        $script = Join-Path $HOME '.local/bin/wrappers/git-clone.ps1'
        if (Test-Path -LiteralPath $script) {
            & $script @args
            return
        }
    }
    & git.exe @args
}
