# Ubuntu

### Prerequirement
- Github CLI
- Chezmoi
- Mise
- NVIM (from snap)
- Zoxide
- FZF
`sudo snap install nvim`

### Usage

**Update chezmoi source after editing a target file directly:**
```bash
chezmoi re-add ~/.tmux.conf
```

**Re-add all modified tracked files:**
```bash
chezmoi re-add
```
