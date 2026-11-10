// Shown as a one-pixel layout block so key commands reach this persistent copy.
import { View, div } from 'gpui-kit';
import { nextCommand, focused, hc, exec, run, notify, shared, setShared } from 'herdr';
const directions = {h: 'left', j: 'down', k: 'up', l: 'right'};
const VIM = /^(?:n?vim(?:diff)?|view|gvim|vimx)$/;

// Herdr holds a terminal's input for ~3 s after nvim enables in-band resize
// reports (CSI ?2048h), so `hc keys` blocks that long on a fresh nvim. nvim
// publishes its RPC address as the `herdr.nvim` label (utils/multiplexer.lua).
// We drive nvim over that RPC socket *on the terminal's own machine* (a remote
// nvim's socket lives there, and `herdr-app` isn't installed there), ask it to
// move one window, and do the pane hop here when it was already at the edge.
// Prints 1 when nvim moved to another window, 0 when it was at the edge.
const VIM_MOVE = `luaeval("(function(k) local w = vim.api.nvim_get_current_win(); pcall(vim.cmd.wincmd, k); return vim.api.nvim_get_current_win() ~= w and 1 or 0 end)(_A)", "KEY")`;

// "my_thor/t3" -> "my_thor"; "t3" -> null (this computer).
const machineOf = (address) => address.includes('/') ? address.slice(0, address.lastIndexOf('/')) : null;

// Returns true when nvim handled the key itself (moved between its windows).
async function sendToVim(terminal, info, key) {
  const server = info.labels?.['herdr.nvim'];
  if (server) {
    const r = await exec('nvim', ['--server', server, '--remote-expr', VIM_MOVE.replace('KEY', key)],
      {on: machineOf(terminal), timeout: 3000}).catch(() => null);
    const out = r?.code === 0 ? r.stdout.trim() : '';
    if (out === '1') return true;
    if (out === '0') return false;
  }
  // No reachable RPC: let nvim's own mapping handle it, if nvim is really there.
  const name = (info.foreground?.name ?? '').split(/[\\/]/).pop();
  if (!VIM.test(name)) return false;
  const r = await hc(['keys', terminal, `ctrl+${key}`]);
  if (r.code !== 0) throw new Error(r.stderr || r.stdout);
  return true;
}

export default class Navigation extends View {
  init(_props, cx) {
    setShared('personal.corner', null);
    // Navigation runs beside the command loop, in order, so a slow terminal
    // never blocks the prefix or later commands.
    this.chain = Promise.resolve();
    cx.spawn(async (cx) => {
      for (;;) {
        const key = await nextCommand();
        if (key === 'dismiss') {
          const target = shared('personal.corner')?.target;
          setShared('personal.corner', null);
          if (target?.pane) run('pane.focus', {pane: target.pane});
          continue;
        }
        if (key === 'prefix' || key === 'links') {
          const current = shared('personal.corner');
          if (key === 'prefix' && current?.mode === 'prefix') {
            const target = current.target;
            setShared('personal.corner', null);
            if (target?.pane) run('pane.focus', {pane: target.pane});
            if (target?.terminal) cx.spawn(async () => {
              try {
                const r = await hc(['keys', target.terminal, 'ctrl+a']);
                if (r.code !== 0) throw new Error(r.stderr || r.stdout);
              } catch (err) { notify({title: 'Prefix', body: String(err), level: 'error'}); }
            });
          } else {
            setShared('personal.corner', {mode: key, target: focused(), nonce: Date.now()});
            run('personal-corner.activate');
          }
          continue;
        }
        const direction = directions[key];
        if (!direction) continue;
        const target = focused();
        this.chain = this.chain.then(() => this.navigate(key, direction, target));
      }
    });
  }
  async navigate(key, direction, target) {
    if (!target?.terminal) { run('pane.go', {direction}); return; }
    try {
      const result = await hc(['get', target.terminal, '--json']);
      if (result.code !== 0) throw new Error(result.stderr || result.stdout);
      const info = JSON.parse(result.stdout);
      const fg = info.foreground;
      const name = (fg?.name ?? fg?.argv?.[0] ?? '').split(/[\\/]/).pop();
      // Never redirect a delayed key to a newly focused terminal.
      if (focused()?.terminal !== target.terminal) return;
      // nvim started through the shell launcher reports its parent shell as the
      // foreground, so a live `herdr.nvim` label (cleared on exit) counts too.
      const isVim = VIM.test(name) || !!info.labels?.['herdr.nvim'];
      if (isVim && await sendToVim(target.terminal, info, key)) return;
      if (focused()?.terminal !== target.terminal) return;
      run('pane.go', {direction});
    } catch (err) {
      notify({title: 'Pane navigation', body: String(err), level: 'error'});
    }
  }
  render() { return div().h(1); }
}
