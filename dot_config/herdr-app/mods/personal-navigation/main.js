// Shown as a one-pixel layout block so key commands reach this persistent copy.
import { View, div } from 'gpui-kit';
import { nextCommand, focused, hc, exec, run, notify, shared, setShared } from 'herdr';
const directions = {h: 'left', j: 'down', k: 'up', l: 'right'};
const VIM = /^(?:n?vim(?:diff)?|view|gvim|vimx)$/;

// Herdr holds a terminal's input for ~3 s after nvim enables in-band resize
// reports (CSI ?2048h), so `hc keys` blocks that long on a fresh nvim. nvim
// publishes its RPC address as the `herdr.nvim` label (utils/multiplexer.lua);
// keys sent there aren't held.
async function sendToVim(terminal, info, key) {
  const server = info.labels?.['herdr.nvim'];
  if (server && info.foreground?.name === 'nvim') {
    const r = await exec('nvim', ['--server', server, '--remote-send', `<C-${key}>`]);
    if (r.code === 0) return;
  }
  const r = await hc(['keys', terminal, `ctrl+${key}`]);
  if (r.code !== 0) throw new Error(r.stderr || r.stdout);
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
      if (VIM.test(name)) await sendToVim(target.terminal, info, key);
      else run('pane.go', {direction});
    } catch (err) {
      notify({title: 'Pane navigation', body: String(err), level: 'error'});
    }
  }
  render() { return div().h(1); }
}
