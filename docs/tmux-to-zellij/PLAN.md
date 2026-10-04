# Plan: Migrate tmux workflow to Zellij

## Goal

Replace tmux (+ TPM, sesh/skim picker, resurrect/continuum, monokai-pro theme, is-vim navigation) with a
Zellij setup managed by chezmoi on **macOS and Arch Linux**, keeping current muscle memory:

- **Prefix `C-a`** tmux-style bindings, with Zellij sitting in **locked mode by default** so nvim, fish and the Pi agent get every key.
- **Seamless `C-h/j/k/l`** between nvim splits and Zellij panes.
- **Built-in `session-manager`** plugin replaces `sesh` + `sk` on `prefix o`.
- **Session resurrection** + Ghostty auto-attach replaces tmux-resurrect + the continuum Ghostty fork.
- **zjstatus** top bar in Monokai colors showing session + tabs only (same as current monokai-pro modules).

Rollout is **coexist, then retire**: tmux stays installed and untouched until the Key Results are met, then it is removed in a separate commit.

### Decisions (from planning Q&A)

| Concern | Decision |
|---|---|
| Rollout | Coexist, then retire tmux |
| Keybinding model | tmux-like prefix `C-a`, `default_mode "locked"` |
| Session picker | Zellij built-in `session-manager` (no zoxide) |
| Vim navigation | Include nvim_config changes (external repo) |
| Persistence | `session_serialization` + Ghostty `command` auto-attach |
| Theme | zjstatus, Monokai colors, pane frames off |
| Platforms | macOS (Brewfile) + Arch (pacman script) |

### Current tmux → Zellij mapping

tmux "window" = Zellij "tab". Prefix mode = Zellij's built-in `tmux` mode, rebound to `C-a`.

| tmux (`dot_tmux.conf`) | Zellij action (in `tmux` mode unless noted) | Notes |
|---|---|---|
| `C-a C-a` send-prefix | `Write 1` | |
| `R` reload config | — | Zellij hot-reloads `config.kdl`; drop |
| `n` new-window (cwd) | `NewTab` | Verify new tab inherits focused pane cwd |
| `s` / `v` split v/h (cwd) | `NewPane "Down"` / `NewPane "Right"` | Panes inherit cwd |
| `-` / `\` 20% split | `NewPane` + `Resize` steps | **Gap**: no size arg; approximate or accept 50% |
| `_` / `\|` full-width split | — | **Gap**: no full-span split; consider stacked/floating panes |
| `x` kill-pane | `CloseFocus` | |
| `X` kill-window | `CloseTab` | |
| `K` kill other windows / kill-session | `Quit` (confirm) or session-manager | **Gap**: no "close other tabs"; `K` binding was duplicated in tmux anyway |
| `S` new session prompt | `LaunchOrFocusPlugin "session-manager"` | New-session tab inside plugin |
| `o` sesh + skim picker | `LaunchOrFocusPlugin "session-manager" { floating true; }` | |
| `r` rename-window | `SwitchToMode "RenameTab"; TabNameInput 0` | |
| `<` / `>` swap-window | `MoveTab "Left"` / `MoveTab "Right"` | |
| copy-mode vi | `SwitchToMode "Scroll"` + vi keys, `/` search | `e` = `EditScrollback` in nvim replaces tmux-fuzzback |
| `C-h/j/k/l` (root, is_vim.sh) | vim-zellij-navigator `MessagePlugin` binds in `locked` + `shared` | See Task 4 |
| `1..9` select window (default) | `GoToTab N` | |
| `z` zoom (default) | `ToggleFocusFullscreen` | |
| `d` detach (default) | `Detach` | |
| `mouse on`, `status-position top` | `mouse_mode true`, bar at top of layout | |
| `extended-keys csi-u` (Pi agent) | `support_kitty_keyboard_protocol true` | Verify Pi agent key combos |

## Tasks

### Phase 0 — Repo prep
- [x] Add `docs` to `.chezmoiignore` so this plan isn't deployed to `~/docs`.
- [x] Add `brew "zellij"` to `Brewfile`; add `zellij` to `run_once_install-pacman-packages.sh.tmpl`.
- [x] `chezmoi apply` on macOS, confirm `zellij --version` (record version; verify config option names against docs for that version via ctx7).

### Phase 1 — Base config (`dot_config/zellij/config.kdl`)
- [x] Generate a starting point with `zellij setup --dump-config`, then trim to an explicit, minimal config.
- [x] Options: `default_mode "locked"`, `mouse_mode true`, `copy_on_select true`, `scrollback_editor "nvim"`, `pane_frames false`, `support_kitty_keyboard_protocol true`, `scroll_buffer_size` (≥ tmux default), `default_shell "fish"`.
- [x] Persistence options: `session_serialization true`, `serialize_pane_viewport true`, `scrollback_lines_to_serialize` (small, e.g. 1000).
- [x] Theme: define a `monokai` theme block (or import from the zellij themes repo) and set `theme "monokai"`.
- [x] Ensure Ghostty `macos-option-as-alt=true` stays (already set) for any Alt binds.

### Phase 2 — Keybindings (prefix `C-a`)
- [x] `keybinds clear-defaults=true { ... }` to avoid Zellij's `Ctrl+p/t/n/s/o/g` defaults stealing keys from nvim/fish.
- [x] `locked`: `Ctrl a` → `SwitchToMode "Tmux"`; plus the `C-h/j/k/l` navigator binds (Task 4).
- [x] `tmux` mode: implement every row of the mapping table above; every action ends with `SwitchToMode "Locked"` (except repeatable ones like `MoveTab`/resize).
- [x] `tmux` mode: `[` → Scroll mode, `e` → `EditScrollback`, `Esc`/`C-a` → back to Locked.
- [x] `scroll`/`search` modes: vi keys (`j/k`, `C-d/C-u`, `g/G`, `/`, `n/N`, `v`/`y` copy where supported), `q`/`Esc` → Locked.
- [x] `resize` mode reachable from prefix (e.g. `prefix` + `C-r` or arrow keys) with `h/j/k/l`.
- [x] Decide workarounds for the three **Gaps** (20% split, full-span split, close-other-tabs); document chosen behaviour in a comment at top of `config.kdl`.

### Phase 3 — Layout & status bar (zjstatus)
- [x] Create `dot_config/zellij/layouts/default.kdl`: zjstatus pane at **top** (`size 1`, `borderless true`), `children` below.
- [x] Configure zjstatus: left = session name, center/left = tabs (active/inactive formats), right = empty; Monokai Pro palette (match `tuananh131001/monokai-pro.tmux`).
- [x] Load zjstatus by pinned release URL (`https://github.com/dj95/zjstatus/releases/download/<ver>/zjstatus.wasm`) so it works on both OSes without extra install steps.
- [x] Set `default_layout "default"`; approve plugin permissions once per machine.

### Phase 4 — nvim ↔ Zellij navigation (external `nvim_config` repo)
- [x] Zellij side: add `vim-zellij-navigator` plugin binds for `Ctrl h/j/k/l` (`MessagePlugin` … `move_focus_or_tab` / `move_focus`) in `locked` (default mode) and `shared_except "locked"`.
- [x] nvim side (in `tuananh131001/nvim_config`): add/configure `smart-splits.nvim` (zellij multiplexer integration) or `zellij-nav.nvim`; remove `vim-tmux-navigator` once tmux is retired (keep both during coexist — check plugin conditions on `$ZELLIJ` / `$TMUX`).
- [x] Verify edge behaviour: `C-l` at the right-most nvim split moves to the Zellij pane on the right; `C-h` from a shell pane enters nvim's right-most split.
- [ ] Verify `C-l` still clears screen in a plain fish pane is acceptable loss (same as today under tmux).

### Phase 5 — Sessions & Ghostty autostart
- [x] Bind `prefix o` and `prefix S` to the built-in `session-manager` (floating); confirm it can create a session with a chosen cwd, switch, kill, and resurrect exited sessions.
- [x] Ghostty: set `command` to attach-or-create a default session (e.g. `zellij attach --create main`). Use `dot_config/ghostty/dot_config.tmpl` (or template `config`) so the zellij path works on both macOS (`/opt/homebrew/bin`) and Arch (`/usr/bin`).
- [x] Keep an escape hatch: a Ghostty keybind or env check to open a plain fish shell without zellij (needed during coexist and for debugging).
- [ ] Test resurrection: reboot / kill server, reopen Ghostty → previous session list and layouts restored; resurrected commands wait behind confirmation prompt.
- [x] Optional fish abbreviations in `dot_config/private_fish/config.fish` (`zj` → `zellij`, `zja` → `zellij attach`, `zjl` → `zellij ls`).

### Phase 6 — Trial period (coexist)
- [ ] Daily-drive Zellij for **2 weeks** on macOS and at least a few days on Arch; tmux remains available via `tmux` command.
- [ ] Keep a friction log at the bottom of this file (missing binding, perf issue, Pi agent key problem) and fix in config.
- [ ] Check Pi agent / Claude Code inside Zellij: Shift+Enter, Ctrl+Enter, Alt keys, mouse scroll, copy to clipboard.

### Phase 7 — Retire tmux (separate commit, only after Key Results are met)
- [ ] Remove `dot_tmux.conf`.
- [ ] Remove TPM + continuum fork clone block from `run_once-packages.sh.tmpl`.
- [ ] Remove `tmux` and `sesh` from `Brewfile`; remove `tmux` and `sesh-bin` (yay) from pacman script.
- [ ] Remove `dot_config/is-vim/` (replaced by vim-zellij-navigator).
- [ ] Remove `vim-tmux-navigator` from nvim_config.
- [ ] Update `README.md` (`chezmoi re-add ~/.tmux.conf` → `chezmoi re-add ~/.config/zellij/config.kdl`).
- [ ] Manually clean `~/.tmux/plugins` on each machine (not managed by chezmoi).

## Implementation notes (2026-10-04)

- Zellij **0.45.1** (Homebrew). Pinned plugins: zjstatus `v0.25.0`, vim-zellij-navigator `0.3.0`.
- Layout is `layouts/monokai.kdl` with `default_layout "monokai"`, not `default.kdl`. Zellij puts the `default_layout` entry first in the session-manager layout picker, but a file named `default` ties with the built-in `default`, and the built-in wins. With a unique name, **name → Enter → Enter** creates a session that has the zjstatus bar.
- Gap workarounds:
  - `-` / `\` 20% split: `NewPane` followed by `~/.local/bin/zellij-sized-split`. The script reads pane geometry (`list-panes --json`) and resizes the new pane with `resize --pane-id` until it is 20% of the original pane. Zellij resizes in fixed steps, so vertical splits land a bit under 20% (44 rows gave 7).
  - `_` / `|` full-span split: Zellij can't split across the whole tab, so both keys toggle floating panes. That opens a scratch pane when none exists.
  - `K` close other tabs: `~/.local/bin/zellij-close-other-tabs`. It finds its own tab through `$ZELLIJ_PANE_ID` and closes every other tab with `close-tab-by-id`. jq is now installed on Arch too.
- `C-a C-a` sends a literal `C-a` (fish start of line). `Esc` or `C-c` leaves prefix mode.
- Scroll mode has no keyboard selection (`v`/`y` from tmux). `y` copies the last command's output, `e` opens the scrollback in nvim, and `copy_on_select` covers the mouse.
- In search mode, `n` searches up (older output) and `N` searches down.
- zjstatus shows a mode badge on the right (PREFIX, SCROLL, ...) **only outside locked mode**. In locked mode the bar is session + tabs only, as before.
- Ghostty `command` runs `fish --login -c "zellij attach --create main; exec fish --login"`. The escape hatch is detach (`C-a d`), which leaves a plain fish shell in the window. `dot_config/ghostty/config` + `dot_config.tmpl` were merged into one `config.tmpl`, because the old `.config` file was never read by Ghostty.
- nvim: `smart-splits.nvim` loads only when `$ZELLIJ` is set and `vim-tmux-navigator` only when it is not, so tmux keeps working during the coexist period. `vim.g.smart_splits_multiplexer_integration` is set in `init`, because auto-detection trusts `TERM_PROGRAM`, and that is wrong when Zellij runs inside tmux.
- Verified in a real terminal (Zellij hosted in a throwaway tmux): every prefix binding, cwd inheritance, the sized splits, `K`, the session manager, nvim↔Zellij navigation in all four cases, and resurrection of an exited session (tabs, names, splits and cwd restored).

## Key Results

1. **Install parity**: a fresh `chezmoi apply` on macOS and Arch installs Zellij and produces a working config with zero manual edits (only the one-time plugin permission prompt).
2. **Keybinding parity**: every binding in `dot_tmux.conf` has a Zellij equivalent under `C-a`, or a documented workaround for the 3 known gaps; 0 Zellij default binds collide with nvim/fish keys (`default_mode "locked"`).
3. **Navigation**: `C-h/j/k/l` moves seamlessly across nvim splits and Zellij panes in all 4 directions, in 100% of manual test cases.
4. **Sessions**: `prefix o` opens session-manager and switches/creates/kills sessions in ≤ 3 keystrokes after typing the name.
5. **Persistence**: after a reboot, opening Ghostty lands in Zellij and all sessions from before the reboot are listed and resurrectable with their tab/pane layout.
6. **Look**: top status bar shows only session name + tabs in Monokai colors; pane frames off.
7. **Agent compatibility**: Pi agent and Claude Code key combos (Shift/Ctrl+Enter, Alt keys) behave identically to tmux with csi-u.
8. **Adoption**: 2 consecutive weeks of daily use with no fallback to `tmux`; then Phase 7 lands and `git grep -i tmux` in this repo returns only historical/plan references.

## Friction log

<!-- Add issues found during the trial period here -->

- **Still to check by hand** (needs a real Ghostty window): `C-l` clearing the screen in a plain fish pane (Phase 4); a real reboot/resurrect (Phase 5); Shift+Enter, Ctrl+Enter, Alt keys, mouse scroll and clipboard in Pi agent / Claude Code (Phase 6); fresh `chezmoi apply` on Arch.
- `dot_config/private_fish/config.fish` in source has drifted from the live `~/.config/fish/config.fish` (live file has OrbStack, pnpm and opencode setup). The `zj`/`zja`/`zjl` abbreviations are in source only. Reconcile with `chezmoi merge ~/.config/fish/config.fish` before applying fish.
