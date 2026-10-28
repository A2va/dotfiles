My dotfiles repo managed with [chezmoi](https://www.chezmoi.io/), it comes preconfigured with a wide range of tools and customizations for different shells. To accomodate other users preferences, you can choose which shell(s) to configure and which groups of software to install, depending on your need.

Choose your preferred shell — these are supported out of the box:

| OS          | Supported shells                      |
| ----------- | ------------------------------------- |
| **Linux**   | Bash, Fish, Nushell                   |
| **Windows** | PowerShell (v7+ recommended), Nushell |

The scripts are mostly based on the work of **Samuel Roland**, which you can find here:

- [samuelroland/dotfiles](https://codeberg.org/samuelroland/dotfiles)
- [samuelroland/productivity](https://codeberg.org/samuelroland/productivity)

> [!NOTE]  
> On Windows, PowerShell v7 or later is recommended, as some features (notably carapace) are not functional in the default Windows PowerShell.

> [!WARNING]  
> Some script may behave slightly differently depanding on the shell, also some script needs external executables like (`fd`, `entr`), only the nushell implementation of it doesn't require anything.

# Installation

On Linux

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
~/.local/bin/chezmoi init --apply A2va
```

On Windows

```
winget install twpayne.chezmoi
chezmoi init --apply A2va
```

During installation, you'll be prompted to:

- Select your default shell (e.g. Fish, Nushell, Bash)
- Choose optional software groups to install (e.g. core tools, developer tools)

# Git clone wrapper

`git clone` is intercepted by a small wrapper (a `git` executable on Linux, a
PowerShell `git` function on Windows). Every other git command is passed
through untouched.

- Paste the HTTPS URL copied from the browser. If an SSH identity is configured
  for the host (`ssh -G`, so `~/.ssh/config` is honoured), the clone uses SSH;
  otherwise it stays on HTTPS.
- If the repository is a fork, an `upstream` remote pointing at the original
  repository is added (always over HTTPS) and fetched. Supported forges:
  GitHub, GitLab, Codeberg/Forgejo/Gitea and Tangled. Unknown hosts are probed
  for the GitLab and Forgejo APIs.

| Variable                  | Effect                                      |
| ------------------------- | ------------------------------------------- |
| `SMART_GIT_NO_UPSTREAM=1` | Skip the fork lookup                        |
| `SMART_GIT_DEBUG=1`       | Print what the wrapper is doing             |
| `SMART_GIT_DRY_RUN=1`     | Print the resulting command without running |

# Software

Depending on your selected package groups, the following tools can be automatically installed and configured:

- Base utilities: [`git`](https://git-scm.com/), [`docker`](https://www.docker.com/), [`starship`](https://starship.rs/), [`carapace`](https://carapace.sh/), [`vivid`](https://github.com/sharkdp/vivid)
- CLI Enhancements: [`zoxide`](https://github.com/ajeetdsouza/zoxide), [`eza`](https://eza.rocks/), [`ripgrep`](https://github.com/BurntSushi/ripgrep), [`fd`](https://github.com/sharkdp/fd), [`bat`](https://github.com/sharkdp/bat), [`fzf`](https://github.com/junegunn/fzf)
- Developer Tools: [`xmake`](https://xmake.io/), [`rustup`](https://rustup.rs/), [`uv`](https://github.com/astral-sh/uv), [`bun`](https://bun.com/)
- Utilities: [`typst`](https://typst.app/), [`vhs`](https://github.com/charmbracelet/vhs), [`yt-dlp`](https://github.com/yt-dlp/yt-dlp), [`gallery-dl`](https://codeberg.org/mikf/gallery-dl)
- GUI: [Zed](https://zed.dev/), [VS Code](https://code.visualstudio.com/), [Anytype](https://anytype.io/), [Syncthing Tray](https://martchus.github.io/syncthingtray/), [KeepassXC](https://keepassxc.org/)
