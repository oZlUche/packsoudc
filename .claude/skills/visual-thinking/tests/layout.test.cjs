'use strict';
const {test,before,after} = require('node:test');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const {inspectSVG} = require('../scripts/inspect-svg.cjs');
const {applyTheme} = require('../scripts/apply-theme.cjs');
let browser;
before(async()=>{browser=await chromium.launch({headless:true,...(process.env.VT_BROWSER_CHANNEL ? {channel:process.env.VT_BROWSER_CHANNEL}: {})});});
after(async()=>{await browser?.close();});
const svg = body => `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400" role="img" aria-labelledby="title"><title id="title">测试关系图</title><desc>通用测试夹具。</desc><style>text{font:24px sans-serif}path,line{stroke:black;fill:none}</style>${body}</svg>`;
async function inspect(body) {
  const page=await browser.newPage();
  try {
    await page.setContent('<style>body{margin:0}</style>'+svg(body));
    await page.evaluate(()=>document.fonts.ready);
    return await page.evaluate(inspectSVG);
  } finally {await page.close();}
}
const kinds = result => result.issues.map(i=>i.kind);
test('intersecting circles are legitimate; contained labels fit',async()=>{
  const r=await inspect('<circle id="a" data-node="" cx="160" cy="150" r="100" fill="none"/><circle id="b" data-node="" cx="290" cy="150" r="100" fill="none"/><text x="115" y="155" data-in-node="a">甲</text><text x="315" y="155" data-in-node="b">乙</text>');
  assert.deepEqual(r.issues,[]);assert.equal(r.coverage.annotatedNodes,2);
});
test('text collisions and canvas overflow are observable',async()=>{
  const r=await inspect('<text x="30" y="40">相同位置</text><text x="32" y="40">碰撞</text><text x="590" y="100">越界</text>');
  assert.ok(kinds(r).includes('text-overlap'));assert.equal(r.overflow.length,1);
});
test('curves are sampled, not just bounding boxes',async()=>{
  const safe=await inspect('<path id="curve" data-edge="" d="M40 180 Q300 -150 560 180"/><text x="250" y="160">留白</text>');
  assert.ok(!kinds(safe).includes('edge-through-text'));
  const hit=await inspect('<path id="curve" data-edge="" d="M40 180 Q300 120 560 180"/><text x="250" y="160">穿字</text>');
  assert.ok(kinds(hit).includes('edge-through-text'));
});
test('nonendpoint node interception is found',async()=>{
  const r=await inspect('<circle id="a" data-node="" cx="50" cy="150" r="25"/><circle id="b" data-node="" cx="550" cy="150" r="25"/><circle id="obstacle" data-node="" cx="300" cy="150" r="25"/><path id="edge" data-edge="" data-from="a" data-to="b" d="M50 150H550"/>');
  assert.equal(r.issues.filter(i=>i.kind==='edge-through-node').length,1);
  assert.equal(r.issues.find(i=>i.kind==='edge-through-node').elements[1],'obstacle');
});
test('mask can clear its own label, but neighboring text is flagged',async()=>{
  const r=await inspect('<path id="e" data-edge="" d="M40 150H560"/><rect id="mask" data-label-mask="label" data-for-edge="e" x="245" y="120" width="110" height="45" fill="white"/><text id="label" data-edge-label="e" x="260" y="155">关系</text><text id="neighbor" x="330" y="138">旁边</text>');
  assert.ok(!r.issues.some(i=>i.kind==='edge-through-text'&&i.elements.includes('label')));
  assert.ok(r.issues.some(i=>i.kind==='mask-near-text'&&i.elements.includes('neighbor')));
});
test('transformed nodes use screen coordinates for padding',async()=>{
  const good=await inspect('<g transform="translate(30 30) scale(1.5)"><circle id="n" data-node="" cx="100" cy="100" r="70"/><text data-in-node="n" x="85" y="105">好</text></g>');
  assert.deepEqual(good.issues,[]);
  const bad=await inspect('<g transform="translate(30 30) scale(1.5)"><circle id="n" data-node="" cx="100" cy="100" r="20"/><text data-in-node="n" x="75" y="105">挤出</text></g>');
  assert.ok(kinds(bad).includes('node-label-padding'));
});
test('hidden text is excluded, visible multiline collisions remain detectable',async()=>{
  const r=await inspect('<g opacity="0"><text x="40" y="50">隐藏</text></g><text x="40" y="50"><tspan x="40" y="50">第一行</tspan><tspan x="40" y="85">第二行</tspan></text>');
  assert.deepEqual(r.issues,[]);assert.equal(r.textElements,1);
});
test('unannotated geometry is reported as unchecked',async()=>{
  const r=await inspect('<path d="M20 40H580"/><text x="20" y="40">未标注</text>');
  assert.equal(r.coverage.annotatedEdges,0);assert.equal(r.coverage.unannotatedGeometry,1);
});
test('explicit overlap exemption needs reason and exact pair',async()=>{
  const body='<text id="a" data-allow-overlap="b" data-overlap-reason="演示重印" x="30" y="40">字</text><text id="b" x="30" y="40">字</text>';
  assert.deepEqual((await inspect(body)).issues,[]);
  assert.ok(kinds(await inspect(body.replace('data-overlap-reason="演示重印"',''))).includes('text-overlap'));
});
test('theme changes preserve all structure outside the dedicated style block',()=>{
  const source=svg('<style data-vt-theme=""></style><circle id="a" cx="100" cy="100" r="40" fill="var(--vt-surface)"/><text x="100" y="100">原文</text>');
  const strip=s=>s.replace(/<style data-vt-theme="[^"]*">[\s\S]*?<\/style>/,'');
  for(const name of ['monochrome','color-blocks','sticker-board'])assert.equal(strip(applyTheme(source,name)),strip(source));
  assert.throws(()=>applyTheme(source,'unknown'));assert.throws(()=>applyTheme(svg(''),'monochrome'));
});
