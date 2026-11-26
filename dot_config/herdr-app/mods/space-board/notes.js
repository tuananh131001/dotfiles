// Space notes, kept in shared "space.notes" = { [spaceId]: { text, updated } }.
// Shared by space-board and space-note.
import { shared, setShared } from "herdr";

export const notes = () => shared("space.notes") ?? {};

export function setNote(id, text) {
  const all = { ...notes() };
  const t = (text ?? "").trim();
  if (t) all[id] = { text: t, updated: Date.now() }; else delete all[id];
  setShared("space.notes", all);
}

export function ago(ms) {
  const m = Math.round((Date.now() - ms) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  if (m < 1440) return `${Math.round(m / 60)}h ago`;
  return `${Math.round(m / 1440)}d ago`;
}
