#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
function themeCSS(name) {
  const spec = JSON.parse(fs.readFileSync(path.join(__dirname, '../assets/themes.json'), 'utf8'));
  const t = spec.themes[name];
  if (!t) throw new Error('Unknown theme. Choose monochrome, color-blocks, or sticker-board.');
  const pairs = Object.entries(t).filter(([key]) => key !== 'name').map(([key, value]) => `--vt-${key}:${value}`);
  pairs.push(...Object.entries(spec.type).map(([key, value]) => `--vt-${key}:${value}px`));
  return `svg{${pairs.join(';')}}`;
}
function applyTheme(svg, name) {
  const marker = /<style\s+data-vt-theme=(?:"[^"]*"|'[^']*')\s*>[\s\S]*?<\/style>/g;
  if ((svg.match(marker) || []).length !== 1) throw new Error('Exactly one <style data-vt-theme=""> block is required.');
  return svg.replace(marker, `<style data-vt-theme="${name}">${themeCSS(name)}</style>`);
}
if (require.main === module) {
  try {
    const [input, output, name, ...extra] = process.argv.slice(2);
    if (!input || !output || !name || extra.length) throw new Error('Usage: node apply-theme.cjs INPUT.svg OUTPUT.svg THEME');
    if (path.resolve(input) === path.resolve(output)) throw new Error('Use a separate output file to retain the original.');
    const result = applyTheme(fs.readFileSync(input, 'utf8'), name);
    fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
    fs.writeFileSync(output, result);
    console.log(JSON.stringify({ output: path.basename(output), theme: name }));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { themeCSS, applyTheme };
