// Vim-aware ctrl+l: forwards to (n)vim when it is focused, else moves pane focus right.

import { View, div } from "gpui-kit";
import { run, props, closeOverlay, focused, terminals, hc } from "herdr";

const VIM = /(^|\/)(n?vim?x?|vimdiff)$/;

export default class Nav extends View {
  init() {
    const p = props();
    if (!p?.overlay) return;
    closeOverlay(p.overlay);
    const term = focused()?.terminal;
    const info = term && terminals().find((x) => x.address === term);
    const fg = info?.foreground?.argv?.[0] ?? "";
    if (VIM.test(fg)) hc(["keys", term, "ctrl+l"]);
    else run("pane.go", { direction: "right" });
  }

  render() {
    return div();
  }
}
