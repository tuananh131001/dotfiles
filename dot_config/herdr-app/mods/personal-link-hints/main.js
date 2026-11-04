// Native port of local.link-hints. Reads only the captured terminal's visible screen.
import { View, div } from 'gpui-kit';
import { v_flex, h_flex } from 'gpui-base';
import { focused, hc, exec, theme, props, closeOverlay, notify, window } from 'herdr';
import { scan } from './links.js';
export default class LinkHints extends View {
  init(_props, cx) {
    this.target = focused()?.terminal;
    this.links = [];
    this.typed = '';
    this.message = 'Reading visible links…';
    this.handle = cx.focus_handle();
    this.handle.focus();
    cx.spawn(async (cx) => {
      try {
        if (!this.target) throw new Error('Focus a terminal first.');
        const r = await hc(['read', this.target, '--lines', '0']);
        if (r.code !== 0) throw new Error(r.stderr || r.stdout);
        this.links = scan(r.stdout);
        this.message = this.links.length ? '' : 'No links were found';
      } catch (err) { this.message = String(err); }
      cx.notify();
    });
  }
  open(url, cx) {
    if (this.opening) return;
    this.opening = true;
    cx.spawn(async (cx) => {
      try {
        if (url.startsWith('www.')) url = 'https://' + url;
        // Always open on the person's computer, even for remote terminal links.
        const r = window().platform === 'macos' ? await exec('open', [url])
          : window().platform === 'windows' ? await exec('rundll32.exe', ['url.dll,FileProtocolHandler', url])
          : await exec('xdg-open', [url]);
        if (r.code !== 0) throw new Error(r.stderr || r.stdout);
        closeOverlay(props().overlay);
      } catch (err) {
        this.opening = false;
        notify({title: 'Link hints', body: String(err), level: 'error'});
        cx.notify();
      }
    });
  }
  render() {
    const t = theme();
    const matches = this.links.filter(h => h.label.startsWith(this.typed));
    return v_flex().id('link-hints').track_focus(this.handle).p(16).gap(8).max_h(520).bg(t.popover).text_color(t.foreground).text_size(13)
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        if (e.key === 'escape' || e.keystroke === 'ctrl-c') return closeOverlay(props().overlay);
        if (this.opening) return;
        if (e.key === 'backspace') this.typed = this.typed.slice(0, -1);
        else if (/^[a-z]$/.test(e.key) && !e.modifiers.control && !e.modifiers.platform && !e.modifiers.alt) this.typed += e.key;
        else return;
        const chosen = this.links.find(h => h.label === this.typed);
        if (chosen) this.open(chosen.url, cx);
        else if (!this.links.some(h => h.label.startsWith(this.typed))) this.typed = '';
        cx.notify();
      })
      .child(div().font_semibold().child(`Link hints ${this.typed ? '· ' + this.typed : ''}`))
      .child(div().text_color(t.muted).child('Type a label or click · Backspace undo · Esc cancel'))
      .when(Boolean(this.message), el => el.child(this.message))
      .child(v_flex().id('links').overflow_y_scrollbar().gap(4).children(matches.map(h =>
        h_flex().id('link-' + h.label).gap(10).p(6).rounded(4).hover(s => s.bg(t.hover))
          .on_click((_e, cx) => this.open(h.url, cx))
          .child(div().text_color(t.accent).font_semibold().child(h.label))
          .child(div().flex_1().truncate().child(h.url)))));
  }
}
