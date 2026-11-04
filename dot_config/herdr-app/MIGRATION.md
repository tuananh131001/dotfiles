# Migration from Herdr TUI

Source: `~/.config/herdr/config.toml` and `~/.config/herdr/plugins.json`.
Original files and running terminals were left untouched.
Backup of the original app keys/settings: `migration-backup-20261104-135258/`.
Original app layout: `main`. Migrated layout: `personal` (a personal clone).

## Settings

- Tokyo Night palette in `themes/tokyo-night.json` (native terminal/theme palette, not a pixel-identical TUI theme).
- Agent state colors: blocked #D55E00, working #F0E442, done #56B4E9, idle #0072B2.
- Sounds disabled.
- `personal-agents`, cloned from shipped agents: grouped by space by default, static state symbols, three lines (state/space/machine; agent; dimmed cleaned terminal title). Remote machine label is #CC79A7.
- Existing zoom, fonts, appearance, contrast and macOS shortcuts retained.
- Native notifications are managed by the new app; old `ui.toast.delivery` has no matching setting.
- Old onboarding and experimental pane-history switches have no equivalent and were not copied as unknown JSON fields.
- Commented settings are not explicit preferences and were not copied. Shell and cwd defaults already match the old macOS follow/login behavior.

## Current design: C (compact corner popover)

In the `personal` layout, both Ctrl+A and Ctrl+A y use `personal-corner`: a 360 px wide, content-sized floating panel anchored at the bottom-right, without background dimming. The prefix panel is approximately 220 px tall; links grow with content up to a scrollable 220 px list. Escape dismisses and restores terminal focus. The navigation mod routes prefix commands and retains Vim-aware movement. The old overlay mods remain as a fallback on other layouts.

Native checks passed for the corner and navigation mods. Screenshots of the prefix and empty-links states were inspected: `~/herdr-prefix-design-c.png` and `~/herdr-links-design-c.png`. No synthetic keyboard input was used for visual verification.

## Keys

`Ctrl+A` opens the compact corner menu in `personal` (the original `personal-prefix` overlay elsewhere). Escape cancels. Ctrl+A again (or a) sends Ctrl+A to the captured terminal. This reserves Ctrl+A's usual start-of-line behavior; use the repeated prefix to access it.

After the prefix:

| Key | Action |
| --- | --- |
| o, w | Native space/tab/agent picker (replacement for goto/workspace picker) |
| c | New tab |
| n, p | Next/previous tab |
| 1–9 | Select tab |
| T | Rename tab |
| X | Close tab |
| N | New space |
| W | Rename space |
| D | Close space |
| h/j/k/l | Focus left/down/up/right |
| Tab, Shift+Tab | Cycle pane forward/backward in model order |
| \| | Split right |
| - | Split down |
| x | Close pane |
| z | Zoom pane |
| b | Toggle sidebar visibility |
| s | Settings |
| ? | Native key help |
| G | Native worktree dialog |
| y | Link Hints |

`Ctrl+H/J/K/L` in the `personal` layout: inspect the focused terminal's foreground process through hc; forward the control key to Vim/Neovim, otherwise focus the neighboring pane. These intentionally take the shell's Backspace/newline/kill-to-end/clear-screen control keys, matching the old custom bindings. Other layouts retain their own behavior. Existing Neovim mappings that call the old `herdr` CLI to cross an editor boundary must separately be changed to call `herdr-app do pane.go --direction ...`.

Not ported: old detach/reload-config actions, pane renaming, external scrollback editor, and keyboard resize mode (no direct native equivalents). Resize with native split dividers. Closing the app window leaves core terminals running. Native ? help lists keys.json, not the prefix's internal secondary-key table; this document is that table.

## Plugins

Registry contained one enabled plugin: `local.link-hints`. Port: `mods/personal-link-hints/`.

- Ctrl+A y opens a native URL picker for the captured terminal's visible screen, including remote terminals.
- Scans http/https, file and www links, newest screen rows first, preserving URL punctuation/balanced parentheses.
- Same home-row alphabet: asdfghjklqwertyuiopzxcvbnm. Fixed-width labels remain unambiguous for large link counts.
- Type a label or click to open locally; Backspace undoes label input, Escape cancels.
- No auto-open of a single URL (same as old defaults).
- Difference: a labeled list instead of painting labels on terminal cells. No-links appears in the dialog instead of a separate notification.
- Uses hc read and local OS URL opener; no network fetches or shell interpolation. Local file URLs can open files, as in the old plugin.

## Validation and rollback

All four personal mods passed `herdr-app check`; status reported no errors. Agent rows, prefix overlay and Link Hints empty-screen dialog were visually inspected via app screenshots. URL parsing/order/label tests passed. Keyboard routing, actual URL launching and Vim boundary navigation still need a manual smoke test; no synthetic keys were sent to the person's running terminal.

To roll back: switch to main (`herdr-app do layout.switch --name main`), restore keys.json and settings.json from the backup. Personal mods/layout/theme can remain unused; no original config or plugin was deleted.
