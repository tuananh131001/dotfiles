// tmux/herdr-tui style prefix: ctrl-a opens this, the next key runs an action.
// Esc (or any unbound key) cancels.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { run, props, closeOverlay, theme, focused, hc } from "herdr";

const ACTIONS = {
  c: ["tab.new"],
  n: ["tab.next"],
  p: ["tab.prev"],
  "shift-x": ["tab.close"],
  "shift-t": ["tab.rename"],
  x: ["pane.close"],
  z: ["pane.zoom"],
  h: ["pane.go", { direction: "left" }],
  j: ["pane.go", { direction: "down" }],
  k: ["pane.go", { direction: "up" }],
  l: ["pane.go", { direction: "right" }],
  "|": ["pane.split", { direction: "right" }],
  "shift-|": ["pane.split", { direction: "right" }],
  "-": ["pane.split", { direction: "down" }],
  b: ["layout.toggle", { id: "sidebar" }],
  o: ["mod.open", { name: "picker" }],
  w: ["mod.open", { name: "picker" }],
  "shift-n": ["space.new"],
  "shift-w": ["space.rename"],
  "shift-d": ["space.close"],
  s: ["app.settings"],
  "?": ["app.help"],
  "shift-?": ["app.help"],
  q: ["app.hide"],
};

export default class Prefix extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  close() {
    closeOverlay(props().overlay);
  }

  render(cx) {
    const t = theme();
    return h_flex()
      .id("prefix")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        const m = e.modifiers;
        if (["shift", "control", "alt", "platform"].includes(e.key)) return;
        this.close();
        // ctrl-a ctrl-a sends a literal ctrl-a to the program.
        if (e.key === "a" && m.control) {
          const term = focused()?.terminal;
          if (term) hc(["keys", term, "ctrl+a"]);
          return;
        }
        // e: open the focused terminal's screen and history in nvim, in a new tab.
        if (e.key === "e" && !m.shift) {
          const term = focused()?.terminal;
          if (!term) return;
          const f = `\${TMPDIR:-/tmp}/herdr-scrollback-${term}.txt`;
          run("tab.new", { name: "scrollback", argv: ["sh", "-c", `hc read ${term} > "${f}"; nvim + "${f}"; rm -f "${f}"`] });
          return;
        }
        if (/^[1-9]$/.test(e.key) && !m.control && !m.alt && !m.platform) {
          run("tab.select", { index: Number(e.key) });
          return;
        }
        const a = ACTIONS[e.keystroke] ?? ACTIONS[e.key_char] ?? ACTIONS[e.key];
        if (a) run(a[0], a[1] ?? {});
      })
      .size_full()
      .px(14)
      .items_center()
      .gap(10)
      .bg(t.popover)
      .text_size(12)
      .text_color(t.muted)
      .child(div().text_color(t.accent).font_semibold().child("PREFIX"))
      .child("c tab · | - split · hjkl move · x close · z zoom · e scrollback · o go · esc");
  }
}
