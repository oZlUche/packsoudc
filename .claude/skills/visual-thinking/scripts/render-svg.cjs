#!/usr/bin/env node
// Optional renderer. Install Playwright separately; see references/rendering.md.
'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const { inspectSVG } = require('./inspect-svg.cjs');

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || !args.length) {
    console.log('Usage: node render-svg.cjs INPUT.svg OUTPUT.png [--scale 2] [--channel chrome]');
    return;
  }
  const [input, output, ...options] = args;
  if (!input || !output || !/\.svg$/i.test(input) || !/\.png$/i.test(output)) {
    throw new Error('Provide an input .svg and a separate output .png.');
  }
  let scale = 2, channel;
  for (let i = 0; i < options.length; i += 2) {
    const [key, value] = options.slice(i, i + 2);
    if (key === '--scale' && value) scale = Number(value);
    else if (key === '--channel' && value) channel = value;
    else throw new Error('Unknown or incomplete option. Use --help.');
  }
  if (!Number.isFinite(scale) || scale <= 0 || scale > 4) throw new Error('Scale must be greater than 0 and at most 4.');
  const svg = await fs.readFile(input, 'utf8');
  // Render self-contained diagrams only. No active or externally loaded content.
  if (/<!DOCTYPE|<!ENTITY|<\s*(script|foreignObject|image)\b|\bon\w+\s*=|@import|@font-face/i.test(svg)) {
    throw new Error('Use a self-contained SVG without scripts, embedded images, event handlers, or external fonts.');
  }
  if (/\b(?:href|src)\s*=\s*['"](?!#)/i.test(svg) || /url\(\s*['"]?(?!#)[^\s'"]/i.test(svg)) {
    throw new Error('External resources are not supported. Use local SVG geometry and system fonts.');
  }
  let chromium;
  try { ({ chromium } = require('playwright')); }
  catch { throw new Error('Playwright is missing. See references/rendering.md for installation and NODE_PATH setup.'); }
  const browser = await chromium.launch({ headless: true, ...(channel ? { channel } : {}) });
  try {
    const page = await browser.newPage({ deviceScaleFactor: scale, javaScriptEnabled: false });
    await page.route('**/*', route => route.abort());
    // Parse as XML first. Invalid markup must not be silently repaired as HTML.
    const size = await page.evaluate(source => {
      const doc = new DOMParser().parseFromString(source, 'image/svg+xml');
      if (doc.querySelector('parsererror')) throw new Error('Invalid SVG XML.');
      const root = doc.documentElement;
      if (root.localName !== 'svg') throw new Error('The root must be svg.');
      const vb = root.getAttribute('viewBox')?.trim().split(/[\s,]+/).map(Number);
      const px = name => {
        const s = root.getAttribute(name) || '';
        return /^\d+(?:\.\d+)?(?:px)?$/.test(s) ? parseFloat(s) : NaN;
      };
      const width = vb?.length === 4 ? vb[2] : px('width');
      const height = vb?.length === 4 ? vb[3] : px('height');
      if (![width, height].every(n => Number.isFinite(n) && n > 0 && n <= 10000)) {
        throw new Error('Provide a valid viewBox or pixel dimensions up to 10000.');
      }
      return { width: Math.ceil(width), height: Math.ceil(height) };
    }, svg);
    if (size.width * size.height * scale * scale > 80000000) throw new Error('Raster is too large; reduce --scale.');
    await page.setViewportSize(size);
    await page.setContent('<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0}svg{display:block}</style></head><body>' + svg + '</body></html>');
    await page.locator('body > svg').evaluate((root, dim) => {
      root.setAttribute('width', dim.width);
      root.setAttribute('height', dim.height);
    }, size);
    await page.evaluate(() => document.fonts.ready);
    const inspection = await page.evaluate(inspectSVG);
    await fs.mkdir(path.dirname(path.resolve(output)), { recursive: true });
    await page.locator('body > svg').screenshot({ path: output, omitBackground: true });
    console.log(JSON.stringify({ output: path.basename(output), ...size, scale, ...inspection,
      note: 'Diagnostics are candidates for review, not a visual or semantic pass. Inspect the PNG. Font stacks do not verify glyph coverage.' }, null, 2));
    if (inspection.overflow.length || inspection.issues.length) process.exitCode = 2;
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
