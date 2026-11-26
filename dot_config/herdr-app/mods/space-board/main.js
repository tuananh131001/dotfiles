// Spaces board: a kanban of spaces, one column per custom status (shared "space.status",
// the same one my-spaces and space-status-menu use), plus "No status".
// Each card: name, machine label, tabs, branch, agent counts, and a note (shared "space.notes")
// that shows while the card is hovered.
// Left click: go to the space (and close the board). Right click: the status menu.
// Drag a card to another column, or hover it and press 1-9 (0 clears), to set its status.
// N (or the ✎ button) edits the hovered card's note.
// "+ New status" adds a column (status); ✕ on a column's header removes it (its spaces go to No status).
// Drag a column by its header to reorder the statuses ("No status" stays first).
// ✎ on a column's header, or double-clicking its name, renames it (spaces keep it).
// The status list is shared with my-spaces and space-status-menu (status.js).

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { spaces, machines, agents, run, openOverlay, closeOverlay, props, theme } from "herdr";
import { statusList, statusDef, assignments, setStatus, addStatus, removeStatus, moveStatus, renameStatus, PALETTE, NONE_ICON } from "./status.js";
import { notes, ago } from "./notes.js";

const NONE = "NONE"; // column key for spaces without a status
const NONE_COL = { label: "No status", color: null, icon: NONE_ICON };
const AGENT_ORDER = ["blocked", "done", "working", "idle"];

const colOf = (id) => assignments()[id] ?? NONE;
const machineLabel = (m) => m ?? "this Mac";

// A note's first lines, at most 3 and ~180 characters.
function preview(text) {
  const lines = text.split("\n").slice(0, 3).join("\n");
  const cut = lines.length > 180 ? lines.slice(0, 180).trimEnd() + "…" : lines;
  return cut + (text.length > cut.length && !cut.endsWith("…") ? "…" : "");
}

export default class SpaceBoard extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.filter = "all"; // "all", "local", or a machine name
    this.hovered = null; // space id under the pointer
    this.pressed = null; // space id pressed with the left button
    this.overCol = null; // column under the pointer while pressing
    this.moved = false; // the press became a drag
    this.adding = false; // the "+ New status" form is open
    this.color = PALETTE[3];
    this.addError = "";
    this.input = InputState.new({ placeholder: "Name, e.g. REVIEW" });
    this.input.on("change", (_e, cx) => { if (this.addError) { this.addError = ""; cx.notify(); } });
    this.input.on("submit", (_e, cx) => this.submitAdd(cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.renaming = null; // status column whose name is being edited
    this.renameError = "";
    this.renameInput = InputState.new({ placeholder: "Status name" });
    this.renameInput.on("change", (_e, cx) => { if (this.renameError) { this.renameError = ""; cx.notify(); } });
    this.renameInput.on("submit", (_e, cx) => this.submitRename(cx));
    this.renameInput.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.renameInput.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.hoverCol = null; // column header under the pointer
    this.removing = null; // column asking "remove?"
    this.colPressed = null; // status column pressed by its header
    this.colOver = null; // status column under the pointer while dragging one
    this.colMoved = false;
  }

  startAdd(cx) {
    if (this.renaming) this.cancelRename(cx);
    this.adding = true;
    this.addError = "";
    this.input.set_value("");
    this.color = PALETTE[statusList().length % PALETTE.length];
    this.input.focus();
    cx.notify();
  }

  startRename(key, cx) {
    const S = statusDef(key);
    if (!S) return;
    if (this.adding) this.cancelAdd(cx);
    this.renaming = key;
    this.removing = null;
    this.renameError = "";
    this.renameInput.set_value(S.label);
    this.renameInput.focus();
    cx.notify();
  }

  cancelRename(cx) {
    this.renaming = null;
    this.renameError = "";
    this.renameInput.blur();
    this.handle.focus();
    cx.notify();
  }

  submitRename(cx) {
    const key = this.renaming;
    if (!key) return;
    const name = this.renameInput.value().trim();
    if (!name) { this.renameError = "Give it a name"; cx.notify(); return; }
    if (name.toUpperCase() !== statusDef(key)?.label && !renameStatus(key, name)) {
      this.renameError = "Another status has that name";
      cx.notify();
      return;
    }
    this.cancelRename(cx);
  }

  cancelAdd(cx) {
    this.adding = false;
    this.input.blur();
    this.handle.focus();
    cx.notify();
  }

  submitAdd(cx) {
    const name = this.input.value().trim();
    if (!name) { this.addError = "Give it a name"; cx.notify(); return; }
    if (!addStatus(name, this.color)) { this.addError = "That status already exists"; cx.notify(); return; }
    this.cancelAdd(cx);
  }

  close() {
    const o = props()?.overlay;
    if (o) closeOverlay(o);
  }

  go(id) {
    run("space.select", { id });
    this.close();
  }

  editNote(id) {
    openOverlay({ mod: "space-note", kind: "dialog", width: 460, height: 300, props: { space: id } });
  }

  statusMenu(id) {
    const height = 48 + 28 * (statusList().length + 1);
    openOverlay({ mod: "space-status-menu", kind: "popup", width: 200, height, at: "pointer", props: { space: id } });
  }

  shown() {
    const all = spaces();
    if (this.filter === "all") return all;
    if (this.filter === "local") return all.filter((s) => s.machine === null);
    return all.filter((s) => s.machine === this.filter);
  }

  render() {
    const t = theme();
    const list = this.shown();
    const nts = notes();
    const ms = machines();
    const offline = (m) => ms.find((x) => x.name === m)?.layout === "unavailable";
    // Agent counts per space, by status.
    const counts = {};
    for (const a of agents()) {
      const c = (counts[a.space] ??= {});
      c[a.status] = (c[a.status] ?? 0) + 1;
    }
    const ctx = { t, nts, offline, counts };

    return v_flex().id("space-board").track_focus(this.handle).size_full().bg(t.canvas).text_size(13).text_color(t.foreground)
      .on_key_down((e, cx) => {
        if (this.typing) {
          if (e.key === "escape") { cx.stop_propagation(); this.renaming ? this.cancelRename(cx) : this.cancelAdd(cx); }
          return;
        }
        if (e.modifiers.platform || e.modifiers.control || e.modifiers.alt) return;
        const id = this.hovered;
        if (!id) return;
        const order = statusList().map((st) => st.id);
        if (e.key === "0") { setStatus(id, null); cx.stop_propagation(); cx.notify(); }
        else if (/^[1-9]$/.test(e.key) && order[Number(e.key) - 1]) { setStatus(id, order[Number(e.key) - 1]); cx.stop_propagation(); cx.notify(); }
        else if (e.key === "n") { this.editNote(id); cx.stop_propagation(); }
      })
      .on_window_mouse_move((e, cx) => {
        if (this.colPressed !== null && e.pressed_button !== "left") { this.endColDrag(); cx.notify(); return; }
        if (this.pressed === null) return;
        if (e.pressed_button !== "left") { this.endPress(); cx.notify(); return; }
        if (!this.moved && this.overCol !== colOf(this.pressed)) { this.moved = true; cx.notify(); }
      })
      .on_window_mouse_up("left", (_e, cx) => {
        if (this.colPressed !== null) {
          const from = this.colPressed, to = this.colOver, moved = this.colMoved;
          this.endColDrag();
          if (moved && to && to !== from) moveStatus(from, statusList().findIndex((st) => st.id === to));
          cx.notify();
          return;
        }
        const id = this.pressed;
        if (id === null) return;
        const col = this.overCol;
        const moved = this.moved;
        this.endPress();
        if (col && col !== colOf(id)) setStatus(id, col === NONE ? null : col);
        else if (!moved && this.hovered === id) { this.go(id); return; }
        cx.notify();
      })
      .child(this.header(list, ctx))
      .child(h_flex().id("board-cols").flex_1().min_h(0).gap(10).p(12).overflow_x_scrollbar()
        .children([NONE, ...statusList().map((st) => st.id)].map((key) => this.column(key, list.filter((s) => colOf(s.id) === key), ctx)))
        .child(this.newColumn(ctx.t)));
  }

  endColDrag() {
    this.colPressed = null;
    this.colOver = null;
    this.colMoved = false;
  }

  endPress() {
    this.pressed = null;
    this.overCol = null;
    this.moved = false;
  }

  header(list, { t, offline }) {
    const used = [...new Set(spaces().map((s) => s.machine))];
    const chip = (key, label, off) => h_flex().id(`chip-${key}`).h(24).px(10).gap(5).items_center().rounded(12).text_size(12)
      .border_1().border_color(this.filter === key ? t.accent : t.border)
      .when(this.filter === key, (el) => el.bg(t.raised).text_color(t.foreground))
      .when(this.filter !== key, (el) => el.text_color(t.muted).hover((s) => s.bg(t.hover)))
      .cursor_pointer()
      .on_click((_e, cx) => { this.filter = key; cx.notify(); })
      .child(label)
      .when(off, (el) => el.child(div().text_color(t.dim).child("· offline")));
    return h_flex().id("board-head").flex_none().h(44).px(16).gap(10).items_center().bg(t.chrome).border_b_1().border_color(t.border)
      .child(div().font_semibold().text_size(14).child("Spaces"))
      .child(div().text_color(t.dim).child(`${list.length} space${list.length === 1 ? "" : "s"}`))
      .child(div().text_size(11).text_color(t.dim).child("drag or 1-9/0 to set status · N note · click to open"))
      .child(div().flex_1())
      .child(chip("all", "All machines", false))
      .children(used.map((m) => chip(m ?? "local", machineLabel(m), m !== null && offline(m))))
      .child(div().id("board-close").size(26).flex().items_center().justify_center().rounded(6).text_color(t.muted)
        .hover((s) => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
        .on_click(() => this.close()).child("✕"));
  }

  column(key, items, ctx) {
    const { t } = ctx;
    const S = key === NONE ? NONE_COL : statusDef(key);
    const color = S.color ?? t.dim;
    const dropping = this.pressed !== null && this.moved && this.overCol === key && colOf(this.pressed) !== key;
    // Reordering columns: where the dragged one would land, on this column's left or right.
    const order = statusList().map((st) => st.id);
    const colTarget = this.colMoved && this.colOver === key && this.colPressed !== key;
    const landsRight = colTarget && order.indexOf(this.colPressed) < order.indexOf(key);
    return v_flex().id(`col-${key}`).flex_1().min_w(200).h_full().rounded(8).overflow_hidden()
      .bg(dropping ? t.raised : t.chrome).border_1().border_color(dropping ? color : t.border)
      .when(colTarget, (el) => el.border_color(t.accent).when(landsRight, (e) => e.border_r_4()).when(!landsRight, (e) => e.border_l_4()))
      .when(this.colMoved && this.colPressed === key, (el) => el.opacity(0.45))
      .on_mouse_move((_e, cx) => {
        if (this.pressed !== null && this.overCol !== key) { this.overCol = key; cx.notify(); }
        if (this.colPressed !== null && key !== NONE && this.colOver !== key) {
          this.colOver = key;
          if (key !== this.colPressed) this.colMoved = true;
          cx.notify();
        }
      })
      .child(div().h(2).flex_none().bg(color))
      .child(this.renaming === key ? this.renameRow(key, color, t) : this.removing === key ? this.removeConfirm(key, S, items.length, t) : h_flex().id(`colh-${key}`).flex_none().h(38).px(12).gap(8).items_center().border_b_1().border_color(t.border)
        .on_hover((h, cx) => {
          if (h) this.hoverCol = key; else if (this.hoverCol === key) this.hoverCol = null;
          cx.notify();
        })
        .when(key !== NONE, (el) => el.cursor_grab().tooltip("Drag to move this column")
          .on_mouse_down("left", (_e, cx) => {
            this.colPressed = key;
            this.colOver = key;
            this.colMoved = false;
            cx.notify();
          }))
        .child(svg(S.icon).size(13).flex_none().text_color(color))
        .child(div().id(`coln-${key}`).min_w(0).truncate().font_semibold().text_size(12.5)
          .when(key !== NONE, (el) => el.on_click((e, cx) => { if (e.click_count === 2) this.startRename(key, cx); }))
          .child(S.label))
        .when(Boolean(S.key), (el) => el.child(div().flex_none().px(4).rounded(3).border_1().border_color(t.border).text_size(10).text_color(t.dim).child(S.key)))
        .child(div().flex_1())
        .child(div().text_color(t.dim).text_size(12).child(String(items.length)))
        .when(key !== NONE && this.hoverCol === key, (el) => el.child(div().id(`cole-${key}`).size(20).flex_none().flex().items_center().justify_center().rounded(4)
          .text_size(11).text_color(t.dim).hover((st) => st.bg(t.hover).text_color(t.foreground)).cursor_pointer()
          .tooltip(`Rename ${S.label}`)
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click((_e, cx) => this.startRename(key, cx))
          .child("✎")))
        .when(key !== NONE && this.hoverCol === key, (el) => el.child(div().id(`colx-${key}`).size(20).flex_none().flex().items_center().justify_center().rounded(4)
          .text_size(11).text_color(t.dim).hover((st) => st.bg(t.hover).text_color(t.blocked)).cursor_pointer()
          .tooltip(`Remove ${S.label}`)
          .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
          .on_click((_e, cx) => { this.removing = key; cx.notify(); })
          .child("✕"))))
      .child(v_flex().id(`cards-${key}`).flex_1().min_h(0).p(8).gap(8).overflow_y_scrollbar()
        .when(items.length === 0, (el) => el.child(div().py(14).text_center().text_size(12).text_color(t.dim)
          .child(dropping ? "Drop here" : "—")))
        .children(items.map((s) => this.card(s, color, ctx))));
  }

  card(s, color, { t, nts, offline, counts }) {
    const hovered = this.hovered === s.id;
    const off = s.machine !== null && offline(s.machine);
    const note = nts[s.id];
    const c = counts[s.id] ?? {};
    const tabs = s.tabs.length;
    const dragging = this.pressed === s.id && this.moved;
    return h_flex().id(`card-${s.id}`).flex_none().w_full().rounded(6).overflow_hidden().items_stretch()
      .bg(hovered ? t.hover : t.surface).border_1().border_color(s.active ? t.accent : t.border)
      .when(off, (el) => el.opacity(0.55))
      .when(dragging, (el) => el.opacity(0.4))
      .cursor_pointer()
      .on_hover((h, cx) => {
        if (h) this.hovered = s.id;
        else if (this.hovered === s.id) this.hovered = null;
        cx.notify();
      })
      .on_mouse_down("left", (_e, cx) => {
        this.pressed = s.id;
        this.overCol = colOf(s.id);
        this.moved = false;
        cx.notify();
      })
      .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); this.statusMenu(s.id); })
      .child(div().w(3).flex_none().bg(color))
      .child(v_flex().flex_1().min_w(0).p(10).gap(6)
        .child(h_flex().gap(6).items_center()
          .child(div().flex_1().min_w(0).truncate().font_semibold().child(s.name))
          .child(hovered ? this.noteButton(s.id, Boolean(note), t) : this.machinePill(s.machine, off, t)))
        .child(h_flex().gap(10).text_size(12).text_color(t.dim)
          .child(`${tabs} tab${tabs === 1 ? "" : "s"}`)
          .when(Boolean(s.branch), (el) => el.child(div().min_w(0).truncate().child(`⎇ ${s.branch}`)))
          .when(off, (el) => el.child(div().text_color(t.blocked).child("machine unreachable")))
          .when(Boolean(note), (el) => el.child(div().text_color(t.accent).child("✎ note"))))
        .when(AGENT_ORDER.some((k) => c[k]), (el) => el.child(h_flex().gap(4).flex_wrap()
          .children(AGENT_ORDER.filter((k) => c[k]).map((k) => h_flex().h(18).px(6).gap(4).items_center().rounded(4).bg(t.raised)
            .text_size(11).text_color(t.muted)
            .child(div().size(7).rounded(4).bg(t[k]))
            .child(`${c[k]} ${k}`)))))
        .when(Boolean(note) && hovered, (el) => el.child(this.notePreview(s.id, note, t))));
  }

  renameRow(key, color, t) {
    return v_flex().id(`colren-${key}`).flex_none().px(10).py(6).gap(4).border_b_1().border_color(t.border)
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .child(h_flex().gap(6).items_center()
        .child(div().size(8).flex_none().rounded(4).bg(color))
        .child(div().flex_1().min_w(0).h(26).px(6).flex().items_center().rounded(5).bg(t.background).border_1().border_color(t.accent).cursor_text()
          .child(Input.new(this.renameInput).w_full().text_size(12.5).text_color(t.foreground)))
        .child(div().id(`colren-ok-${key}`).size(22).flex_none().flex().items_center().justify_center().rounded(4).cursor_pointer()
          .text_color(t.done).hover((st) => st.bg(t.hover)).tooltip("Save (Enter)")
          .on_click((_e, cx) => this.submitRename(cx)).child("✓"))
        .child(div().id(`colren-no-${key}`).size(22).flex_none().flex().items_center().justify_center().rounded(4).cursor_pointer()
          .text_color(t.dim).hover((st) => st.bg(t.hover)).tooltip("Cancel (Esc)")
          .on_click((_e, cx) => this.cancelRename(cx)).child("✕")))
      .when(Boolean(this.renameError), (el) => el.child(div().text_size(11).text_color(t.blocked).child(this.renameError)));
  }

  removeConfirm(key, S, count, t) {
    const btn = (id, label, danger, onClick) => h_flex().id(id).h(22).px(8).items_center().rounded(4).text_size(11).cursor_pointer()
      .bg(danger ? t.blocked : t.raised).text_color(danger ? "#ffffff" : t.foreground).hover((st) => st.opacity(0.85))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { onClick(); cx.notify(); })
      .child(label);
    return v_flex().id(`colrm-${key}`).flex_none().px(12).py(8).gap(6).border_b_1().border_color(t.border).bg(t.raised)
      .child(div().text_size(12).child(`Remove ${S.label}?`))
      .child(div().text_size(11).text_color(t.dim).child(count ? `${count} space${count === 1 ? "" : "s"} go${count === 1 ? "es" : ""} to No status.` : "No spaces have it."))
      .child(h_flex().gap(6).justify_end()
        .child(btn(`colrm-no-${key}`, "Cancel", false, () => { this.removing = null; }))
        .child(btn(`colrm-yes-${key}`, "Remove", true, () => { this.removing = null; this.hoverCol = null; removeStatus(key); })));
  }

  newColumn(t) {
    if (!this.adding) {
      return h_flex().id("col-new").self_start().flex_none().w(180).h(40).rounded(8).border_1().border_color(t.border)
        .items_center().justify_center().gap(6).text_size(12).text_color(t.muted)
        .hover((st) => st.bg(t.hover).text_color(t.foreground)).cursor_pointer()
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click((_e, cx) => this.startAdd(cx))
        .child("+ New status");
    }
    const btn = (id, label, primary, onClick) => h_flex().id(id).h(26).px(10).items_center().rounded(5).text_size(12).cursor_pointer()
      .when(primary, (el) => el.bg(t.solid).text_color(t.solid_foreground))
      .when(!primary, (el) => el.bg(t.raised).border_1().border_color(t.border).text_color(t.foreground))
      .hover((st) => st.opacity(0.85))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => onClick(cx))
      .child(label);
    return v_flex().id("col-new").self_start().flex_none().w(240).p(12).gap(10).rounded(8).bg(t.chrome).border_1().border_color(t.accent)
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .child(h_flex().gap(8).items_center()
        .child(div().size(10).rounded(5).bg(this.color))
        .child(div().font_semibold().text_size(12.5).child("New status")))
      .child(div().h(30).px(8).flex().items_center().rounded(6).bg(t.background).border_1()
        .border_color(this.typing ? t.accent : t.input).cursor_text()
        .child(Input.new(this.input).w_full().text_size(12.5).text_color(t.foreground)))
      .child(h_flex().flex_wrap().gap(6).children(PALETTE.map((c) => div().id(`sw-${c}`).size(18).rounded(9).bg(c).cursor_pointer()
        .border_2().border_color(this.color === c ? t.foreground : "#00000000")
        .on_click((_e, cx) => { this.color = c; cx.notify(); }))))
      .when(Boolean(this.addError), (el) => el.child(div().text_size(11).text_color(t.blocked).child(this.addError)))
      .child(h_flex().gap(6).justify_end()
        .child(btn("new-cancel", "Cancel", false, (cx) => this.cancelAdd(cx)))
        .child(btn("new-add", "Add", true, (cx) => this.submitAdd(cx))));
  }

  machinePill(m, off, t) {
    return h_flex().flex_none().h(18).px(7).gap(4).items_center().rounded(4).bg(t.raised).border_1().border_color(t.border)
      .text_size(11).text_color(m === null ? t.accent : t.muted)
      .child(div().size(6).rounded(3).bg(off ? t.blocked : t.done))
      .child(machineLabel(m));
  }

  noteButton(id, has, t) {
    return h_flex().id(`note-btn-${id}`).flex_none().h(18).px(7).items_center().rounded(4).bg(t.raised).border_1().border_color(t.border)
      .text_size(11).text_color(t.muted).hover((s) => s.text_color(t.foreground).border_color(t.accent))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); this.editNote(id); })
      .child(has ? "✎ Edit note" : "✎ Note");
  }

  notePreview(id, note, t) {
    return v_flex().id(`note-${id}`).p(8).gap(2).rounded(4).bg(t.canvas).border_1().border_color(t.border)
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); this.editNote(id); })
      .child(h_flex().text_size(10).text_color(t.dim).child(div().flex_1().child("✎ note")).child(ago(note.updated)))
      .child(div().text_size(12).text_color(t.muted).whitespace_normal().child(preview(note.text)));
  }
}
