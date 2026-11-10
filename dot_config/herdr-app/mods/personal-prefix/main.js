// Ctrl+A prefix: a snacks.nvim / which-key style hint popup in the bottom-right corner.
// No terminal input is sent on cancellation.
import { View, div } from 'gpui-kit';
import { v_flex, h_flex } from 'gpui-base';
import { run, theme, props, closeOverlay, focused, hc, notify, panes, settings, nextCommand, readTextFile, writeTextFile, appHome } from 'herdr';

// [key, description, command, args]; grouped like which-key's columns.
const GROUPS = [
  { name: 'tabs', items: [
    ['c', 'new tab', 'tab.new'], ['n', 'next tab', 'tab.next'], ['p', 'prev tab', 'tab.prev'],
    ['1-9', 'select tab'], ['T', 'rename tab', 'tab.rename'], ['X', 'close tab', 'tab.close'],
  ]},
  { name: 'panes', items: [
    ['|', 'split right', 'pane.split', {direction: 'right'}], ['-', 'split down', 'pane.split', {direction: 'down'}],
    ['h j k l', 'focus ←↓↑→'], ['tab', 'cycle panes'],
    ['z', 'zoom', 'pane.zoom'], ['x', 'close pane', 'pane.close'],
  ]},
  { name: 'spaces', items: [
    ['o', 'go to…', 'mod.open', {name: 'picker'}], ['N', 'new space', 'space.new'],
    ['W', 'rename space', 'space.rename'], ['D', 'close space', 'space.close'],
    ['G', 'worktree', 'mod.open', {name: 'worktree'}],
  ]},
  { name: 'app', items: [
    ['y', 'link hints', 'mod.open', {name: 'personal-link-hints'}], ['b', 'sidebar', 'layout.toggle', {id: 'sidebar'}],
    ['s', 'settings', 'app.settings'], ['?', 'help', 'app.help'],
  ]},
];

const bindings = {
  '/': ['app.help'], w: ['mod.open', {name: 'picker'}],
  h: ['pane.go', {direction: 'left'}], j: ['pane.go', {direction: 'down'}],
  k: ['pane.go', {direction: 'up'}], l: ['pane.go', {direction: 'right'}],
};
for (const g of GROUPS) for (const [k, , cmd, args] of g.items) if (cmd) bindings[k] = [cmd, args];
for (let i = 1; i <= 9; i++) bindings[String(i)] = ['tab.select', {index: i}];

const SCALE = 0.825; // overall size of the hint popup (1 = original)
const u = (n) => n * SCALE;
const PANEL_W = u(760), PANEL_H = u(236), MARGIN_R = 16, MARGIN_B = 36; // px at zoom 1; bottom clears the status bar

// The popup is placed by mod.json's overlay `at` (bottom-right of the window). It is a single
// overlay, opened by Ctrl+A (mod.open), so it gets the keyboard like any popup. When it closes it
// re-checks the window size and, if it changed, rewrites `at` for the next time.
const MOD_JSON = () => `${appHome()}/mods/personal-prefix/mod.json`;

async function placement() {
  let w = 1280, h = 800;
  try {
    const b = JSON.parse(await readTextFile(`${appHome()}/window.json`) ?? '{}').bounds;
    if (b) { w = b[2]; h = b[3]; }
  } catch {}
  const z = settings().zoom ?? 1;
  return { x: Math.round(Math.max(0, w - (PANEL_W + MARGIN_R) * z)),
           y: Math.round(Math.max(0, h - (PANEL_H + MARGIN_B) * z)) };
}

export default class Prefix extends View {
  init(_props, cx) {
    this.target = focused();
    this.handle = cx.focus_handle();
    this.handle.focus();
    // Herdr/GPUI use Tab for focus movement, so it never reaches on_key_down. Bind Tab and
    // Shift+Tab to our own actions, only inside this popup's key context.
    cx.bind_keys([
      { keystroke: 'tab', action: 'prefix_next_pane', context: 'PersonalPrefix' },
      { keystroke: 'shift-tab', action: 'prefix_prev_pane', context: 'PersonalPrefix' },
    ]);
    // keys.json "mod:personal-prefix": ctrl-a -> personal-prefix.send-prefix
    cx.spawn(async (cx) => {
      for (;;) { if (await nextCommand() === 'send-prefix') this.sendPrefix(cx); }
    });
  }
  async close() {
    try {
      const text = await readTextFile(MOD_JSON());
      const conf = JSON.parse(text);
      const at = await placement();
      const o = conf.overlay ?? {};
      if (o.at?.x === at.x && o.at?.y === at.y && o.width === Math.round(PANEL_W) && o.height === Math.round(PANEL_H)) return;
      conf.overlay = { kind: 'popup', frame: 'none', width: Math.round(PANEL_W), height: Math.round(PANEL_H), at };
      await writeTextFile(MOD_JSON(), JSON.stringify(conf) + '\n', text);
    } catch {}
  }
  done() { closeOverlay(props().overlay); }
  cyclePane(step) {
    this.done();
    const list = panes().filter(p => p.tab === this.target?.tab);
    const i = list.findIndex(p => p.pane === this.target?.pane);
    const next = list[(i + step + list.length) % list.length];
    if (next) run('pane.focus', {pane: next.pane});
  }
  sendPrefix(cx) {
    if (!this.target?.terminal) return this.done();
    cx.spawn(async () => {
      try {
        const r = await hc(['keys', this.target.terminal, 'ctrl+a']);
        if (r.code !== 0) throw new Error(r.stderr || r.stdout);
      } catch (err) { notify({title: 'Prefix', body: String(err), level: 'error'}); }
      this.done();
    });
  }
  onKey(e, cx) {
    cx.stop_propagation();
    if (e.key === 'escape' || e.keystroke === 'ctrl-c') return this.done();
    if (e.keystroke === 'ctrl-a' || (e.key === 'a' && !e.modifiers.shift)) return this.sendPrefix(cx);
    this.done();
    if (e.key === 'tab') return this.cyclePane(e.modifiers.shift ? -1 : 1);
    let key = e.key;
    if (e.modifiers.shift && /^[a-z]$/.test(key)) key = key.toUpperCase();
    if (e.modifiers.shift && key === '\\') key = '|';
    if (e.modifiers.shift && key === '/') key = '?';
    const action = !e.modifiers.control && !e.modifiers.platform && !e.modifiers.alt && bindings[key];
    if (action) run(action[0], action[1] ?? {});
    else notify({title: 'Prefix', body: `No action for ${e.keystroke}`, level: 'info'});
  }
  render() {
    const t = theme();
    const mono = settings().font_family ?? 'JetBrains Mono';
    const row = ([k, desc]) => h_flex().gap(u(6)).items_center().h(u(20))
      .child(div().w(u(48)).flex().justify_end().text_color(t.ansi3 ?? t.accent).font_semibold().child(k))
      .child(div().text_color(t.dim).child('➜'))
      .child(div().text_color(t.foreground).truncate().child(desc));
    const column = (g) => v_flex().flex_1().min_w(0).gap(u(0))
      .child(h_flex().gap(u(6)).h(u(20)).items_center()
        .child(div().w(u(48)).flex().justify_end().text_color(t.ansi5 ?? t.accent).child('+'))
        .child(div().text_color(t.ansi5 ?? t.accent).font_semibold().child(g.name)))
      .children(g.items.map(row));
    const pill = (k, label) => h_flex().gap(u(4)).items_center()
      .child(div().px(u(5)).rounded(u(3)).bg(t.raised).text_color(t.foreground).child(k))
      .child(div().text_color(t.muted).child(label));

    const panel = v_flex().id('prefix-panel')
      .bg(t.popover).border(1).border_color(t.accent).rounded(u(8)).shadow_lg()
      .font_family(mono).text_size(u(12.5))
      // title, centered like a floating-window border title
      .child(h_flex().justify_center().pt(u(8)).pb(u(4))
        .child(div().px(u(8)).rounded(u(4)).bg(t.accent).text_color(t.accent_foreground).font_semibold().child(' <C-a> ')))
      .child(h_flex().flex_1().px(u(12)).pt(u(4)).gap(u(16)).items_start().children(GROUPS.map(column)))
      // footer like which-key's  <esc> close  <c-a> send prefix
      .child(h_flex().justify_center().gap(u(18)).pb(u(8)).pt(u(4)).text_size(u(11.5))
        .child(pill('esc', 'close'))
        .child(pill('a / C-a', 'send prefix'))
        .child(pill('S-tab', 'prev pane')));
    return panel.size_full().key_context('PersonalPrefix').track_focus(this.handle)
      .on_action('prefix_next_pane', () => this.cyclePane(1))
      .on_action('prefix_prev_pane', () => this.cyclePane(-1))
      .on_key_down((e, cx) => this.onKey(e, cx));
  }
}
