'use strict';
// Passed directly to Playwright evaluate. No external state or dependencies.
function inspectSVG() {
  const root = document.querySelector('body > svg');
  const canvas = root.getBoundingClientRect();
  const issues = [];
  const rect = element => {
    const b = element.getBoundingClientRect();
    return { left: b.left, top: b.top, right: b.right, bottom: b.bottom, width: b.width, height: b.height };
  };
  const shown = e => {
    for (let n = e; n && n !== root.parentElement; n = n.parentElement) {
      const s = getComputedStyle(n);
      if (s.display === 'none' || s.visibility === 'hidden' || Number(s.opacity) === 0) return false;
    }
    return true;
  };
  const texts = [...root.querySelectorAll('text')].filter(shown);
  const label = e => e.id || (e.textContent || '').trim().slice(0, 48) || e.localName;
  const intersect = (a, b, tolerance = 1) => Math.min(a.right, b.right) - Math.max(a.left, b.left) > tolerance && Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > tolerance;
  const points = (b, pad = 0) => {
    const l = b.left - pad, r = b.right + pad, t = b.top - pad, d = b.bottom + pad;
    return [[l,t],[r,t],[l,d],[r,d],[(l+r)/2,t],[(l+r)/2,d],[l,(t+d)/2],[r,(t+d)/2],[(l+r)/2,(t+d)/2]];
  };
  const inRect = (p, b, pad = 1) => p.x > b.left - pad && p.x < b.right + pad && p.y > b.top - pad && p.y < b.bottom + pad;
  const inFill = (shape, x, y) => {
    try {
      const p = new DOMPoint(x, y).matrixTransform(shape.getScreenCTM().inverse());
      return shape.isPointInFill(p);
    } catch { return false; }
  };
  const allow = (a, b) => [a,b].some((e,i) => {
    const other = i === 0 ? b : a;
    return other.id && e.getAttribute('data-overlap-reason')?.trim() && (e.getAttribute('data-allow-overlap') || '').split(/\s+/).includes(other.id);
  });
  const add = (kind, elements, detail) => issues.push({ kind, elements: elements.map(label), ...detail });
  // Separate positioned tspan lines, so empty space between lines is not a label.
  const boxes = texts.flatMap(text => {
    const spans = [...text.querySelectorAll('tspan')].filter(e => e.textContent.trim() && !e.querySelector('tspan'));
    const direct = [...text.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
    return (spans.length && !direct ? spans : [text]).map(part => ({ node: text, part, b: rect(part) }));
  }).filter(x => x.b.width > 0 && x.b.height > 0);
  const overflow = texts.filter(t => {
    const b = rect(t);
    return b.left < canvas.left - 1 || b.top < canvas.top - 1 || b.right > canvas.right + 1 || b.bottom > canvas.bottom + 1;
  }).map(t => ({ text: label(t), bounds: rect(t) }));
  for (let i=0; i<boxes.length; i++) for (let j=i+1; j<boxes.length; j++) {
    const a=boxes[i], b=boxes[j];
    if (intersect(a.b,b.b) && !allow(a.node,b.node)) add('text-overlap',[a.part,b.part],{});
  }
  const nodes = [...root.querySelectorAll('[data-node]')].filter(shown);
  const edges = [...root.querySelectorAll('[data-edge]')].filter(shown);
  const masks = [...root.querySelectorAll('[data-label-mask]')].filter(shown);
  const geometry = e => e instanceof SVGGeometryElement;
  for (const e of [...nodes,...edges,...masks]) {
    if (!geometry(e)) add('annotation-unsupported',[e],{ detail:'Mark a geometry element, not a group.' });
    if (!e.id) add('annotation-missing-id',[e],{});
  }
  for (const e of [...root.querySelectorAll('[data-allow-overlap]')]) {
    if (!e.getAttribute('data-overlap-reason')?.trim()) add('annotation-missing-reason',[e],{});
  }
  for (const {node,part,b} of boxes) {
    const target = node.getAttribute('data-in-node');
    if (!target) continue;
    const shape = document.getElementById(target);
    if (!shape || !geometry(shape) || !shape.hasAttribute('data-node')) { add('annotation-invalid-node',[node],{ target }); continue; }
    const padding = Number(node.getAttribute('data-padding') || 6);
    if (!Number.isFinite(padding) || padding < 0) { add('annotation-invalid-padding',[node],{}); continue; }
    if (!points(b,padding).every(([x,y]) => inFill(shape,x,y))) add('node-label-padding',[part,shape],{ padding });
  }
  for (const edge of edges.filter(geometry)) {
    const endpoints = [edge.getAttribute('data-from'), edge.getAttribute('data-to')].filter(Boolean);
    for (const id of endpoints) if (!nodes.some(n => n.id === id)) add('annotation-invalid-endpoint',[edge],{ target:id });
    const matrix = edge.getScreenCTM();
    const len = edge.getTotalLength();
    const scale = Math.max(Math.hypot(matrix.a,matrix.b), Math.hypot(matrix.c,matrix.d));
    const steps = Math.min(10000, Math.max(2, Math.ceil(len*scale/2)));
    const samples = Array.from({length:steps+1},(_,i) => {
      const p=edge.getPointAtLength(len*i/steps);
      return new DOMPoint(p.x,p.y).matrixTransform(matrix);
    });
    for (const {node,part,b} of boxes) {
      if (allow(edge,node)) continue;
      // A named mask may intentionally clear the edge under its own label.
      const intentional = node.getAttribute('data-edge-label') === edge.id && masks.some(mask => mask.getAttribute('data-label-mask') === node.id && mask.getAttribute('data-for-edge') === edge.id);
      if (!intentional && samples.some(p=>inRect(p,b))) add('edge-through-text',[edge,part],{});
    }
    for (const node of nodes.filter(geometry)) {
      if (endpoints.includes(node.id) || allow(edge,node)) continue;
      if (samples.some(p=>inFill(node,p.x,p.y))) add('edge-through-node',[edge,node],{});
    }
  }
  for (const mask of masks.filter(geometry)) {
    const owner = document.getElementById(mask.getAttribute('data-label-mask'));
    if (!owner || owner.localName !== 'text') add('annotation-invalid-mask-label',[mask],{});
    for (const {node,part,b} of boxes) {
      if (owner === node || allow(mask,node) || !intersect(rect(mask),b,0)) continue;
      // Conservative warning: bounding boxes may intersect without painted pixels touching.
      add('mask-near-text',[mask,part],{ detail:'Review painted overlap and draw order.' });
    }
    for (const node of nodes.filter(geometry)) {
      if (allow(mask,node) || !intersect(rect(mask),rect(node),0)) continue;
      add('mask-near-node',[mask,node],{ detail:'Review boundary occlusion; bounding-box candidate.' });
    }
  }
  const unannotatedGeometry = [...root.querySelectorAll('path,line,polyline,polygon,circle,ellipse,rect')].filter(e=>shown(e) && !e.closest('defs,clipPath,mask,marker') && !e.hasAttribute('data-node') && !e.hasAttribute('data-edge') && !e.hasAttribute('data-label-mask') && !e.hasAttribute('data-decoration')).length;
  const names = (root.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean);
  const descriptions = (root.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean);
  const accessibility = { descriptionReferencesValid:descriptions.length>0 && descriptions.every(id=>root.querySelector('[id="'+CSS.escape(id)+'"]')?.textContent.trim()), role:root.getAttribute('role'), title:!!root.querySelector(':scope > title')?.textContent.trim(), description:!!root.querySelector(':scope > desc')?.textContent.trim(), nameReferencesValid:names.length>0 && names.every(id=>root.querySelector('[id="'+CSS.escape(id)+'"]')?.textContent.trim()) };
  return { textElements:texts.length, overflow, issues, accessibility,
    coverage:{ annotatedNodes:nodes.length, annotatedEdges:edges.length, annotatedMasks:masks.length, unannotatedGeometry, note:'Only marked geometry is checked for path collisions, label padding and masks. Unmarked geometry is not a pass.' },
    fontFamilies:[...new Set(texts.map(n=>getComputedStyle(n).fontFamily))] };
}
module.exports = { inspectSVG };
