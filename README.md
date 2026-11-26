## Quick Setup

`sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply tuananh131001`

This installs the core CLI packages only. Supported: macOS (brew), Arch (pacman),
Fedora incl. the KDE Plasma edition (dnf; tools Fedora doesn't package — skim,
bottom, jaq, sops, yazi, bitwarden-cli — come from mise, and Geist Mono Nerd Font
is installed into `~/.local/share/fonts`).

### Desktop packages (Arch / Fedora KDE, opt-in)

On Fedora the `gui` group installs KDE-native apps (filelight, partitionmanager,
plasma-systemmonitor, dolphin, haruna, vlc, plus Bitwarden from Flathub) and
`terminal` pulls ghostty from the
`scottames/ghostty` COPR. On Arch, `gui` also installs the Bitwarden desktop app.

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
