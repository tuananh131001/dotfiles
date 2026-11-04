export const alphabet = 'asdfghjklqwertyuiopzxcvbnm';
export function scan(text) {
  const links = [];
  for (const line of text.split('\n').reverse()) {
    const pattern = /https?:\/\/[^\s<>"\x00-\x1f]+|file:\/\/[^\s<>"\x00-\x1f]+|www\.[^\s<>"\x00-\x1f]+/g;
    for (const match of line.matchAll(pattern)) {
      if (match[0].startsWith('www.') && /[\w/.]/.test(line[match.index - 1] ?? '')) continue;
      let url = match[0];
      for (;;) {
        const last = url.slice(-1);
        if (/[.,;:!?'"}]/.test(last) && last) url = url.slice(0, -1);
        else if ((last === ')' || last === ']') && url.split(last).length > url.split(last === ')' ? '(' : '[').length) url = url.slice(0, -1);
        else break;
      }
      if (/^(?:https?:\/\/|file:\/\/|www\.).+/.test(url)) links.push(url);
    }
  }
  // Fixed-width labels are prefix-free; unlike the old plugin, support > alphabet² links.
  let width = 1;
  while (alphabet.length ** width < links.length) width++;
  return links.map((url, i) => {
    let label = '';
    for (let j = 0; j < width; j++) { label = alphabet[i % alphabet.length] + label; i = Math.floor(i / alphabet.length); }
    return {url, label};
  });
}
