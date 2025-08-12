My dotfiles repo managed with [chezmoi](https://www.chezmoi.io/), it comes preconfigured with a wide range of tools and customizations for different shells. To accomodate other users preferences, you can choose which shell(s) to configure and which groups of software to install, depending on your need.

Choose your preferred shell — these are supported out of the box:
| OS          | Supported shells                      |
| ----------- | ------------------------------------- |
| **Linux**   | Bash, Fish, Nushell                   |
| **Windows** | PowerShell (v7+ recommended), Nushell |

The scripts are mostly based on the work of **Samuel Roland**, which you can find here:
* [samuelroland/dotfiles](https://codeberg.org/samuelroland/dotfiles)
* [samuelroland/productivity](https://codeberg.org/samuelroland/productivity)

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
* Select your default shell (e.g. Fish, Nushell, Bash)
* Choose optional software groups to install (e.g. core tools, developer tools)

# Software

Depending on your selected package groups, the following tools can be automatically installed and configured:
* Base utilities: [`git`](https://git-scm.com/), [`docker`](https://www.docker.com/)
* CLI Enhancements: [`starship`](https://starship.rs/), [`carapace`](https://carapace.sh/), [`zoxide`](https://github.com/ajeetdsouza/zoxide), [`fzf`](https://github.com/junegunn/fzf), [`eza`](https://eza.rocks/), [`fd`](https://github.com/sharkdp/fd), [`bat`](https://github.com/sharkdp/bat), [`ripgrep`](https://github.com/BurntSushi/ripgrep)
* Developer Tools: [`xmake`](https://xmake.io/), [`rustup`](https://rustup.rs/), [`uv`](https://github.com/astral-sh/uv)
* Utilities: [`typst`](https://typst.app/), [`vhs`](https://github.com/charmbracelet/vhs) 
* GUI: [VS Code](https://code.visualstudio.com/), [Anytype](https://anytype.io/), [Syncthing Tray](https://martchus.github.io/syncthingtray/)

