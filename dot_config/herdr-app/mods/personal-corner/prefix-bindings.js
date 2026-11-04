// Secondary keys preserved from the original prefix configuration.
export const bindings = {
  '?': ['app.help'], '/': ['app.help'],
  s: ['app.settings'], o: ['mod.open', {name: 'picker'}], w: ['mod.open', {name: 'picker'}],
  N: ['space.new'], W: ['space.rename'], D: ['space.close'],
  c: ['tab.new'], T: ['tab.rename'], p: ['tab.prev'], n: ['tab.next'], X: ['tab.close'],
  '|': ['pane.split', {direction: 'right'}], '-': ['pane.split', {direction: 'down'}],
  x: ['pane.close'], z: ['pane.zoom'], b: ['layout.toggle', {id: 'sidebar'}],
  h: ['pane.go', {direction: 'left'}], j: ['pane.go', {direction: 'down'}],
  k: ['pane.go', {direction: 'up'}], l: ['pane.go', {direction: 'right'}],
  G: ['mod.open', {name: 'worktree'}]
};
for (let i = 1; i <= 9; i++) bindings[String(i)] = ['tab.select', {index: i}];
