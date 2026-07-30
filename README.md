## Quick Setup

`sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply tuananh131001`

This installs the core CLI packages only.

### Desktop packages (Arch, opt-in)

GUI apps, the terminal emulator, and the fcitx5 input method are **not** installed
automatically. Run them yourself after `chezmoi apply`:

```bash
~/.local/bin/install-desktop-packages.sh all       # everything
~/.local/bin/install-desktop-packages.sh gui       # baobab, nautilus, vlc, ...
~/.local/bin/install-desktop-packages.sh terminal  # ghostty
~/.local/bin/install-desktop-packages.sh input     # fcitx5 + unikey
```

Run with no arguments to see the full group listing.

### Usage

**Update chezmoi source after editing a target file directly:**
```bash
chezmoi re-add ~/.tmux.conf
```

**Re-add all modified tracked files:**
```bash
chezmoi re-add
```
