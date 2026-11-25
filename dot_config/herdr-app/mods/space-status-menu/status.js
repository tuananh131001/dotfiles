// Space status: shared by my-spaces, space-status-menu and space-board (keep the copies identical).
// The list is editable: shared "space.statuses" = [{ id, label, color, icon? }], in order.
// Without it, the three built-ins below. A space's status: shared "space.status" = { [spaceId]: id }.
// Okabe-Ito colours (safe for protanopia); each status also has its own shape and label.
import { shared, setShared } from "herdr";

export const DEFAULTS = [
  { id: "TODO", label: "TODO", color: "#9aa3b2", icon: "mods/my-spaces/status-todo.svg" },
  { id: "IN_PROGRESS", label: "IN PROGRESS", color: "#e69f00", icon: "mods/my-spaces/status-progress.svg" },
  { id: "DONE", label: "DONE", color: "#56b4e9", icon: "mods/my-spaces/status-done.svg" },
];
export const NONE_ICON = "mods/my-spaces/status-none.svg";
export const CUSTOM_ICON = "mods/my-spaces/status-custom.svg";
// Colours offered for a new status.
export const PALETTE = ["#9aa3b2", "#e69f00", "#56b4e9", "#009e73", "#f0e442", "#0072b2", "#d55e00", "#cc79a7", "#b48ead"];

const raw = () => {
  const l = shared("space.statuses");
  return Array.isArray(l) ? l : DEFAULTS;
};

// Every status, in order, with its icon, a soft background and its number key (1..9).
export function statusList() {
  return raw().map((s, i) => ({ ...s, icon: s.icon ?? CUSTOM_ICON, bg: `${s.color}24`, key: i < 9 ? String(i + 1) : "" }));
}
export const statusDef = (id) => (id ? statusList().find((s) => s.id === id) ?? null : null);

// Space id -> status id, leaving out statuses that no longer exist.
export function assignments() {
  const known = new Set(raw().map((s) => s.id));
  return Object.fromEntries(Object.entries(shared("space.status") ?? {}).filter(([, v]) => known.has(v)));
}
export function setStatus(spaceId, status) {
  const all = { ...(shared("space.status") ?? {}) };
  if (status) all[spaceId] = status; else delete all[spaceId];
  setShared("space.status", all);
}

// Adds a status at the end. Returns its id, or null when the label is empty or taken.
export function addStatus(label, color) {
  const name = (label ?? "").trim();
  if (!name) return null;
  const list = raw();
  if (list.some((s) => s.label.toLowerCase() === name.toLowerCase())) return null;
  const base = name.toUpperCase().replace(/[^A-Z0-9]+/g, "_").replace(/^_|_$/g, "") || "STATUS";
  let id = base;
  for (let n = 2; list.some((s) => s.id === id); n++) id = `${base}_${n}`;
  setShared("space.statuses", [...list, { id, label: name.toUpperCase(), color: color ?? PALETTE[list.length % PALETTE.length] }]);
  return id;
}

// Removes a status; its spaces go back to no status.
export function removeStatus(id) {
  setShared("space.statuses", raw().filter((s) => s.id !== id));
  const all = { ...(shared("space.status") ?? {}) };
  for (const [k, v] of Object.entries(all)) if (v === id) delete all[k];
  setShared("space.status", all);
}

// Moves a status to `index` in the list (0-based); the order is the board's columns, the
// sidebar's status groups, and the menu's number keys.
export function moveStatus(id, index) {
  const list = [...raw()];
  const from = list.findIndex((s) => s.id === id);
  if (from < 0) return;
  const [item] = list.splice(from, 1);
  list.splice(Math.max(0, Math.min(index, list.length)), 0, item);
  setShared("space.statuses", list);
}

// Renames a status; its id (and so every space that has it) stays. Returns false when the
// name is empty or another status already has it.
export function renameStatus(id, label) {
  const name = (label ?? "").trim().toUpperCase();
  if (!name) return false;
  const list = raw();
  if (list.some((s) => s.id !== id && s.label.toUpperCase() === name)) return false;
  setShared("space.statuses", list.map((s) => (s.id === id ? { ...s, label: name } : s)));
  return true;
}
