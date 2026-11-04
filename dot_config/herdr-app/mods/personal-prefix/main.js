// Compatibility layer for the old Ctrl+A prefix. No terminal input is sent on cancellation.
import { View, div } from 'gpui-kit';
import { v_flex } from 'gpui-base';
import { run, theme, props, closeOverlay, focused, hc, notify, nextCommand, panes } from 'herdr';

export const bindings = {
  '?': ['app.help'], '/': ['app.help'],
  s: ['app.settings'], o: ['mod.open', {name: 'picker'}], w: ['mod.open', {name: 'picker'}],
  N: ['space.new'], W: ['space.rename'], D: ['space.close'],
  c: ['tab.new'], T: ['tab.rename'], p: ['tab.prev'], n: ['tab.next'], X: ['tab.close'],
  '|': ['pane.split', {direction: 'right'}], '-': ['pane.split', {direction: 'down'}],
  x: ['pane.close'], z: ['pane.zoom'], b: ['layout.toggle', {id: 'sidebar'}],
  h: ['pane.go', {direction: 'left'}], j: ['pane.go', {direction: 'down'}],
  k: ['pane.go', {direction: 'up'}], l: ['pane.go', {direction: 'right'}],
  y: ['mod.open', {name: 'personal-link-hints'}],
  G: ['mod.open', {name: 'worktree'}],
};
for (let i = 1; i <= 9; i++) bindings[String(i)] = ['tab.select', {index: i}];

export default class Prefix extends View {
  init(_props, cx) {
    this.target = focused();
    this.handle = cx.focus_handle();
    this.handle.focus();
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command !== 'send-prefix') continue;
        try {
          if (this.target?.terminal) {
            const r = await hc(['keys', this.target.terminal, 'ctrl+a']);
            if (r.code !== 0) throw new Error(r.stderr || r.stdout);
          }
        } catch (err) { notify({title: 'Prefix', body: String(err), level: 'error'}); }
        closeOverlay(props().overlay);
      }
    });
  }
  render() {
    const t = theme();
    return v_flex().id('prefix').track_focus(this.handle).p(14).gap(6).bg(t.popover).text_color(t.foreground).text_size(13)
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        if (e.key === 'escape' || e.keystroke === 'ctrl-c') return closeOverlay(props().overlay);
        // Double-prefix sends the original Ctrl+A (start of line) to the program.
        if (e.keystroke === 'ctrl-a' || e.key === 'a' && !e.modifiers.shift) {
          if (this.target?.terminal) cx.spawn(async () => {
            try {
              const r = await hc(['keys', this.target.terminal, 'ctrl+a']);
              if (r.code !== 0) throw new Error(r.stderr || r.stdout);
            }
            catch (err) { notify({title: 'Prefix', body: String(err), level: 'error'}); }
            closeOverlay(props().overlay);
          });
          else closeOverlay(props().overlay);
          return;
        }
        closeOverlay(props().overlay);
        if (e.key === 'tab') {
          const list = panes().filter(p => p.tab === this.target?.tab);
          const index = list.findIndex(p => p.pane === this.target?.pane);
          const next = list[(index + (e.modifiers.shift ? -1 : 1) + list.length) % list.length];
          if (next) run('pane.focus', {pane: next.pane});
          return;
        }
        let key = e.key;
        if (e.modifiers.shift && /^[a-z]$/.test(key)) key = key.toUpperCase();
        if (e.modifiers.shift && key === '\\') key = '|';
        if (e.modifiers.shift && key === '/') key = '?';
        const action = !e.modifiers.control && !e.modifiers.platform && !e.modifiers.alt && bindings[key];
        if (action) run(action[0], action[1] ?? {});
        else notify({title: 'Prefix', body: `No migrated action for ${e.keystroke}. Esc cancels.`, level: 'info'});
      })
      .child(div().font_semibold().child('Ctrl+A · next key'))
      .child('c new tab · n/p next/previous · 1–9 select · o go to')
      .child('| split right · - split down · h/j/k/l focus · z zoom · x close')
      .child('N new space · W rename space · T rename tab · y link hints')
      .child(div().text_color(t.muted).child('b sidebar · s settings · ? help · Esc cancel · Ctrl+A send prefix'));
  }
}
