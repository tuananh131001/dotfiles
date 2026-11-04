// Content-sized, bottom-right floating picker shared by prefix and Link Hints.
import { View, div } from 'gpui-kit';
import { v_flex, h_flex } from 'gpui-base';
import { shared, setShared, theme, run, hc, exec, window, panes, notify, nextCommand } from 'herdr';
import { bindings } from './prefix-bindings.js';
import { scan } from './links.js';

export default class Corner extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === 'activate' || command === 'focus') this.activate(cx);
      }
    });
  }
  activate(cx) {
    const state = shared('personal.corner');
    if (!state) return;
    this.active = state.nonce;
    this.target = state.target;
    this.typed = '';
    this.links = [];
    this.opening = false;
    this.message = 'Reading links…';
    // Acquire focus from a command/event, never as a side effect of render.
    this.focusPending = true;
    this.handle.focus();
    cx.notify();
    if (state.mode !== 'links') return;
    const nonce = state.nonce;
    const terminal = this.target?.terminal;
    cx.spawn(async (cx) => {
      try {
        if (!terminal) throw new Error('Focus a terminal first.');
        const r = await hc(['read', terminal, '--lines', '0']);
        if (r.code !== 0) throw new Error(r.stderr || r.stdout);
        if (this.active !== nonce) return;
        this.links = scan(r.stdout);
        this.message = this.links.length ? '' : 'No links were found';
      } catch (err) { if (this.active === nonce) this.message = String(err); }
      cx.notify();
    });
  }
  dismiss() {
    const target = this.target;
    setShared('personal.corner', null);
    this.active = null;
    if (target?.pane) run('pane.focus', {pane: target.pane});
    else if (target?.terminal) run('pane.focus', {terminal: target.terminal});
  }
  open(url, cx) {
    if (this.opening) return;
    this.opening = true;
    cx.spawn(async (cx) => {
      try {
        if (url.startsWith('www.')) url = 'https://' + url;
        const r = window().platform === 'macos' ? await exec('open', [url])
          : window().platform === 'windows' ? await exec('rundll32.exe', ['url.dll,FileProtocolHandler', url])
          : await exec('xdg-open', [url]);
        if (r.code !== 0) throw new Error(r.stderr || r.stdout);
        this.dismiss();
      } catch (err) { this.opening = false; notify({title: 'Link hints', body: String(err), level: 'error'}); cx.notify(); }
    });
  }
  prefix(e, cx) {
    const target = this.target;
    if (e.key === 'a' && !e.modifiers.shift) {
      cx.spawn(async () => {
        try {
          if (target?.terminal) {
            const r = await hc(['keys', target.terminal, 'ctrl+a']);
            if (r.code !== 0) throw new Error(r.stderr || r.stdout);
          }
        } catch (err) { notify({title: 'Prefix', body: String(err), level: 'error'}); }
        this.dismiss();
      });
      return;
    }
    let key = e.key;
    if (e.modifiers.shift && /^[a-z]$/.test(key)) key = key.toUpperCase();
    if (e.modifiers.shift && key === '\\') key = '|';
    if (e.modifiers.shift && key === '/') key = '?';
    if (key === 'y' && !e.modifiers.control && !e.modifiers.platform && !e.modifiers.alt) {
      setShared('personal.corner', {mode: 'links', target, nonce: Date.now()});
      this.activate(cx);
      return;
    }
    this.dismiss();
    if (key === 'tab') {
      const list = panes().filter(p => p.tab === target?.tab);
      const index = list.findIndex(p => p.pane === target?.pane);
      const next = list[(index + (e.modifiers.shift ? -1 : 1) + list.length) % list.length];
      if (next) run('pane.focus', {pane: next.pane});
      return;
    }
    const action = !e.modifiers.control && !e.modifiers.platform && !e.modifiers.alt && bindings[key];
    if (action) run(action[0], action[1] ?? {});
    else notify({title: 'Prefix', body: `No migrated action for ${e.keystroke}.`, level: 'info'});
  }
  render(cx) {
    const state = shared('personal.corner');
    if (!state) { this.active = null; return div().w(0).h(0); }
    // Key focus and asynchronous reads are initialized by activate(), not render().
    const t = theme();
    const links = state.mode === 'links';
    const label = text => div().w(18).flex_none().text_color(t.accent).font_semibold().child(text);
    const body = v_flex().w_full().px(8).py(4).gap(1);
    if (links) {
      if (this.message) body.child(div().px(4).py(6).text_color(t.muted).child(this.message));
      body.child(v_flex().id('corner-links').max_h(220).overflow_y_scrollbar().children(
        this.links.filter(h => h.label.startsWith(this.typed)).map(h => h_flex().id('hint-' + h.label).gap(6).px(4).h(25).items_center().rounded(4)
          .hover(s => s.bg(t.hover)).on_click((_e, cx) => this.open(h.url, cx))
          .child(label(h.label)).child(div().flex_1().truncate().child(h.url.replace(/^https?:\/\//, ''))))));
    } else {
      for (const [key, text] of [['c','New tab     n/p Next/previous'], ['1–9','Select tab   o Go to'], ['| / -','Split right/down'], ['hjkl','Focus pane   z Zoom   x Close'], ['N/W','New/rename space   T Rename tab'], ['y','Link hints   b Sidebar   s Settings']]) {
        body.child(h_flex().gap(8).h(24).items_center().child(div().w(36).flex_none().text_color(t.accent).font_semibold().child(key)).child(div().truncate().child(text)));
      }
    }
    return v_flex().id('personal-corner').track_focus(this.handle).w(360).max_w(360).text_size(11).text_color(t.foreground)
      .bg(t.popover).border(1).border_color(t.border).rounded(8)
      .on_size_change((_size, cx) => {
        if (this.focusPending) { this.focusPending = false; this.handle.focus(); }
      })
      .on_mouse_down('left', (_e, cx) => cx.stop_propagation())
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        if (e.key === 'escape' || e.keystroke === 'ctrl-c') return this.dismiss();
        if (!links) return this.prefix(e, cx);
        if (this.opening) return;
        if (e.key === 'backspace') this.typed = this.typed.slice(0, -1);
        else if (/^[a-z]$/.test(e.key) && !e.modifiers.control && !e.modifiers.platform && !e.modifiers.alt) this.typed += e.key;
        else return;
        const match = this.links.find(h => h.label === this.typed);
        if (match) this.open(match.url, cx);
        else if (!this.links.some(h => h.label.startsWith(this.typed))) this.typed = '';
        cx.notify();
      })
      .child(h_flex().px(12).h(29).items_center().justify_between().border_b(1).border_color(t.border)
        .child(div().font_semibold().child(links ? `Links${this.typed ? ' · ' + this.typed : ''}` : 'Ctrl+A · next key'))
        .child(div().text_size(10).text_color(t.dim).child('Esc')))
      .child(body)
      .child(div().px(12).pb(6).text_size(10).text_color(t.dim).child(links ? 'Type a label to open' : '? Help · Ctrl+A send prefix'));
  }
}
