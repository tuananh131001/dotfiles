// Space status: shared by my-spaces and space-status-menu.
// Okabe-Ito colours (safe for protanopia); each status also has its own shape and label.
export const STATUSES = ["IN_PROGRESS", "TODO", "DONE"]; // group order
export const MENU_ORDER = ["TODO", "IN_PROGRESS", "DONE"];
export const STATUS = {
  TODO: { label: "TODO", color: "#9aa3b2", bg: "#9aa3b21f", icon: "mods/my-spaces/status-todo.svg", key: "1" },
  IN_PROGRESS: { label: "IN PROGRESS", color: "#e69f00", bg: "#e69f0024", icon: "mods/my-spaces/status-progress.svg", key: "2" },
  DONE: { label: "DONE", color: "#56b4e9", bg: "#56b4e924", icon: "mods/my-spaces/status-done.svg", key: "3" },
};
export const NONE_ICON = "mods/my-spaces/status-none.svg";
