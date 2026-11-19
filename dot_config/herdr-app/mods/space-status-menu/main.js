// Popup to set a space's status. props { space, overlay }.
// Writes shared "space.status" = { [spaceId]: "TODO" | "IN_PROGRESS" | "DONE" }.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { props, closeOverlay, theme, shared, setShared, spaces } from "herdr";
import { STATUS, MENU_ORDER } from "./status.js";

export function setStatus(id, status) {
  const all = { ...(shared("space.status") ?? {}) };
  if (status) all[id] = status; else delete all[id];
  setShared("space.status", all);
}

export default class SpaceStatusMenu extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    const cur = (shared("space.status") ?? {})[props()?.space];
    this.at = Math.max(0, MENU_ORDER.indexOf(cur));
  }

  choose(status) {
    const p = props();
    setStatus(p.space, status);
    closeOverlay(p.overlay);
  }

  render() {
    const t = theme();
    const p = props() ?? {};
    const cur = (shared("space.status") ?? {})[p.space];
    const name = spaces().find((s) => s.id === p.space)?.name ?? "Status";
    const items = [...MENU_ORDER, ...(cur ? [null] : [])];
    const option = (s, i) => h_flex().id(`st-${s ?? "none"}`).h(28).px(8).gap(9).rounded(6).items_center()
      .when(i === this.at, (el) => el.bg(t.selected))
      .hover((st) => st.bg(t.hover))
      .on_click(() => this.choose(s))
      .child(div().w(12).flex_none().text_size(12).text_color(t.accent).child(s && s === cur ? "✓" : ""))
      .when(Boolean(s), (el) => el
        .child(svg(STATUS[s].icon).size(12).flex_none().text_color(STATUS[s].color))
        .child(div().flex_1().text_color(t.foreground).child(s))
        .child(div().text_size(11).text_color(t.dim).child(STATUS[s].key)))
      .when(!s, (el) => el.child(div().flex_1().text_color(t.muted).child("Clear status")).child(div().text_size(11).text_color(t.dim).child("0")));
    return v_flex().id("space-status-menu").track_focus(this.handle).w_full().p(5).bg(t.popover).text_size(12.5)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") return closeOverlay(p.overlay);
        if (k === "1" || k === "2" || k === "3") return this.choose(MENU_ORDER[Number(k) - 1]);
        if (k === "0" && cur) return this.choose(null);
        if (k === "down") this.at = (this.at + 1) % items.length;
        else if (k === "up") this.at = (this.at + items.length - 1) % items.length;
        else if (k === "enter") return this.choose(items[this.at]);
        else return;
        cx.notify();
      })
      .child(div().px(8).pt(4).pb(5).text_size(11).text_color(t.dim).truncate().child(name))
      .children(items.map((s, i) => i === MENU_ORDER.length
        ? v_flex().child(div().mx(7).my(3).h(1).bg(t.border)).child(option(s, i))
        : option(s, i)));
  }
}
