# Ubuntu
## Quick Setup

`sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply tuananh131001`

### Usage

**Update chezmoi source after editing a target file directly:**
```bash
chezmoi re-add ~/.tmux.conf
```

**Re-add all modified tracked files:**
```bash
chezmoi re-add
```
