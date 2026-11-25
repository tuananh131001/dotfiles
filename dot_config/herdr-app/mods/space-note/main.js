// Dialog to write a space's note. props { space, overlay }.
// Writes shared "space.notes" = { [spaceId]: { text, updated } }; an empty note deletes it.
// ⌘↵ / Ctrl+↵ saves, Esc cancels.

import { View, div } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea } from "gpui-base";
import { props, closeOverlay, theme, spaces } from "herdr";
import { notes, setNote, ago } from "./notes.js";

export default class SpaceNote extends View {
  init() {
    const id = props()?.space;
    this.existing = notes()[id] ?? null;
    this.text = this.existing?.text ?? "";
    this.state = TextareaState.new({ placeholder: "What is this space for? Next step, links, reminders…", value: this.text, rows: 8 });
    this.state.set_soft_wrap(true);
    this.state.on("change", () => { this.text = this.state.value(); });
    this.state.on("focus", (_e, cx) => { this.focused = true; cx.notify(); });
    this.state.on("blur", (_e, cx) => { this.focused = false; cx.notify(); });
    this.state.focus();
  }

  close() {
    this.state?.release();
    this.state = null;
  }

  save(text) {
    const p = props() ?? {};
    if (p.space) setNote(p.space, text ?? this.state?.value() ?? this.text);
    closeOverlay(p.overlay);
  }

  render() {
    const t = theme();
    const p = props() ?? {};
    const space = spaces().find((s) => s.id === p.space);
    const button = (id, label, kind, onClick) => h_flex().id(id).h(28).px(12).items_center().rounded(6).text_size(12).cursor_pointer()
      .when(kind === "primary", (el) => el.bg(t.solid).text_color(t.solid_foreground).hover((s) => s.opacity(0.9)))
      .when(kind !== "primary", (el) => el.bg(t.raised).border_1().border_color(t.border).text_color(kind === "danger" ? t.blocked : t.foreground).hover((s) => s.bg(t.hover)))
      .on_click(() => onClick())
      .child(label);

    return v_flex().id("space-note").size_full().p(14).gap(10).bg(t.popover).text_color(t.foreground)
      .on_key_down((e, cx) => {
        if (e.key === "enter" && (e.modifiers.platform || e.modifiers.control)) { cx.stop_propagation(); this.save(); }
        else if (e.key === "escape") { cx.stop_propagation(); closeOverlay(p.overlay); }
      })
      .child(h_flex().gap(8).items_center()
        .child(div().font_semibold().text_size(13).child("Note"))
        .child(div().text_color(t.dim).child("·"))
        .child(div().flex_1().min_w(0).truncate().text_size(13).child(space?.name ?? "Space"))
        .child(h_flex().h(18).px(7).items_center().rounded(4).bg(t.raised).border_1().border_color(t.border)
          .text_size(11).text_color(space?.machine ? t.muted : t.accent).child(space?.machine ?? "this Mac")))
      .child(div().id("note-box").flex_1().min_h(0).p(8).rounded(6).bg(t.background).border_1()
        .border_color(this.focused ? t.accent : t.input).cursor_text()
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .child(Textarea.new(this.state).size_full().text_size(12.5).text_color(t.foreground)))
      .child(h_flex().gap(8).items_center()
        .child(div().flex_1().text_size(11).text_color(t.dim)
          .child(this.existing ? `edited ${ago(this.existing.updated)} · ⌘↵ save · Esc cancel` : "⌘↵ save · Esc cancel"))
        .when(Boolean(this.existing), (el) => el.child(button("note-delete", "Delete note", "danger", () => this.save(""))))
        .child(button("note-cancel", "Cancel", "plain", () => closeOverlay(p.overlay)))
        .child(button("note-save", "Save", "primary", () => this.save())));
  }
}
