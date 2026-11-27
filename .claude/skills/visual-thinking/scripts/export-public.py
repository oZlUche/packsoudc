#!/usr/bin/env python3
"""Export an isolated, validated public preview; never publishes or grants a license."""
from pathlib import Path
from urllib.parse import unquote
import argparse,json,re,shutil,zipfile

EXCLUDED_DOCS={'bubble-adjacency.md','bubble-viewpoints.md','cashflows.md'}
LOCAL_IDS={'20','39','41'}

def strip_sections(text,pattern):
    lines=text.splitlines(keepends=True);out=[];skip=None
    for line in lines:
        m=re.match(r'^(#{1,6})\s+(.+)',line)
        if skip is not None:
            if m and len(m[1])<=skip:skip=None
            else:continue
        if m and re.search(pattern,m[2]):skip=len(m[1]);continue
        out.append(line)
    return ''.join(out)

def local_link(block):
    return 'assets/reference-only/' in block or any(re.search(r'\]\([^)]*'+re.escape(n),block) for n in EXCLUDED_DOCS)

def clean_markdown(text):
    text=re.sub(r'<!-- LOCAL-ONLY:START -->.*?<!-- LOCAL-ONLY:END -->','',text,flags=re.S)
    # Tables are line based: remove a local row, not its entire family table.
    text='\n'.join(line for line in text.splitlines() if not (line.startswith('|') and (local_link(line) or re.match(r'^\|\s*(20|39|41)\s*\|',line))))
    return '\n\n'.join(block for block in text.split('\n\n') if not local_link(block)).rstrip()+'\n'

def anchors(path):
    seen={};result=set()
    for line in path.read_text().splitlines():
        m=re.match(r'^#{1,6}\s+(.+?)(?:\s+#+)?$',line)
        if not m:continue
        h=re.sub(r'\[([^]]+)\]\([^)]*\)',r'\1',m[1].lower());h=re.sub(r'[^\w\s\-]','',h).replace(' ','-')
        n=seen.get(h,0);seen[h]=n+1;result.add(h if not n else f'{h}-{n}')
    return result

def validate(root):
    errors=[];links=0
    for md in root.rglob('*.md'):
        text=md.read_text()
        if re.search(r'/(?:Users|Volumes)/|[A-Z]:\\Users\\',text):errors.append(f'private path: {md.relative_to(root)}')
        for href in re.findall(r'\]\(([^)]+)\)',text)+re.findall(r'(?:src|href)="([^"]+)"',text):
            if ':' in href or href.startswith('/'):continue
            part,sep,frag=href.partition('#');target=(md.parent/unquote(part)).resolve() if part else md;links+=1
            if not target.is_relative_to(root):errors.append(f'outside export: {href}');continue
            if not target.exists():errors.append(f'missing {md.relative_to(root)}: {href}')
            elif sep and frag and target.suffix=='.md' and unquote(frag) not in anchors(target):errors.append(f'anchor {md.relative_to(root)}: {href}')
    idx=json.loads((root/'assets/skeleton-index.json').read_text())
    if len(idx['items'])!=38:errors.append('public index must contain 38 available entries')
    for item in idx['items']:
        if item['kind']=='reference' or item['id'] in LOCAL_IDS:errors.append(f'local entry: {item["id"]}')
        p=root/item['source_asset']
        if not p.exists() or not p.with_suffix('.png').exists():errors.append(f'missing skeleton pair: {item["id"]}')
    for p in root.rglob('*'):
        if p.is_symlink():errors.append(f'symlink: {p.relative_to(root)}')
        if p.is_file() and p.suffix in {'.md','.json','.svg','.yaml','.cjs','.py'}:
            if re.search(r'/(?:Users|Volumes)/|[A-Z]:\\Users\\',p.read_text()):errors.append(f'private path: {p.relative_to(root)}')
    if errors:raise RuntimeError('\n'.join(errors))
    return {'entries':38,'relative_links_and_anchors':links,'license':'MIT; original project material only' if (root/'LICENSE').is_file() else 'not selected; public preview, not a publication','scope':'no reference-only assets or local-use guides','image_review':'requires human review; link checks do not inspect PNG pixels'}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('output',type=Path);args=parser.parse_args()
    source=Path(__file__).resolve().parents[1];out=args.output.expanduser().resolve();dest=out/'visual-thinking'
    if out==source or source in out.parents:raise SystemExit('Output must be outside the maintained skill.')
    if dest.exists():raise SystemExit(f'Refusing to overwrite existing export: {dest}')
    out.mkdir(parents=True,exist_ok=True)
    def ignore(directory,names):
        skipped={n for n in names if n.startswith('.') or n in {'__pycache__','node_modules','Thumbs.db'} or n.endswith(('.pyc','.bak','.tmp'))}
        if Path(directory)==source/'assets':skipped.add('reference-only')
        if Path(directory)==source/'references':skipped.update(EXCLUDED_DOCS)
        return skipped
    for p in source.rglob('*'):
        if p.is_symlink():raise SystemExit(f'Review source symlink before export: {p.relative_to(source)}')
    shutil.copytree(source,dest,ignore=ignore)
    idx=dest/'assets/skeleton-index.json';d=json.loads(idx.read_text());d['items']=[e for e in d['items'] if e['kind']!='reference'];d.pop('retired',None);d['numbering']='stable ids; 38 public entries; names and actual assets are authoritative'
    for e in d['items']:e.pop('legacy_id',None)
    idx.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    for md in dest.rglob('*.md'):
        text=md.read_text()
        if md.name=='skeleton-use-cards.md':
            text=strip_sections(text,r'^(20|39|41)\s');text=text.replace('不是41种经过实验验证的思维模型','不是经过逐项实验验证的思维模型')
        elif md.name=='skeleton-library.md':
            text=strip_sections(text,r'^当前范围与编号$')
            prefix='''## 当前范围与编号

公开预览含38个可用入口，以[主索引](../assets/skeleton-index.json)为准。保留原有稳定编号，空位不代表缺文件或待恢复。按名称、用途与实际文件选图，不根据编号推断质量。

07与34为组合样张，其余为通用骨架。素材与文字分别保留实际来源，不宣称发明既有教学方法。圆、方框、边界和连接是正式图的真实构件；可调整比例与同类对象数量，不能删成文章段落。无数据不以大小、线宽或重复数编码重要性与概率。

'''
            at=text.index('## 关系索引');text=text[:at]+prefix+text[at:]
        elif md.name=='visual-recognition.md':
            text=strip_sections(text,r'^20、39、41：');start=text.index('## 按图形家族进入');text='# 视觉辨认参考：按所用关系查看\n\n覆盖当前公开索引中的38个入口。先读用途卡，再查看相关家族图，核对形状身份、相近图区别和可做的推演；仅看过文件名不算检查。实际效果与来源边界分别核对。\n\n'+text[start:]
        elif md.name=='examples.md':text=strip_sections(text,r'^概念普及：先读懂对象，再沿图思考$')
        elif md.name=='ATTRIBUTION.md' and '## 仅本地保留的参考提取稿' in text:
            prefix=text[:text.index('## 仅本地保留的参考提取稿')]
            notes=[b for b in text.split('\n\n') if b.startswith(('12「','08「','11「','14「','19、22、23','40「'))]
            text=prefix+'## 公开素材的具体编排\n\n'+'\n\n'.join(notes)+'\n\n本公开预览仅包含当前索引中的38项自绘／自主组合入口；未附带作者或再分发状态未核实的来源参考构图。删除这些素材不表示放弃必要的方法署名；真实使用效果仍需单独验证。\n'
        text=clean_markdown(text)
        if md.name=='README.md' and '本公开版本包含38个可用条目。' not in text:text=text.replace('以[当前索引]','本公开版本包含38个可用条目。以[当前索引]')
        md.write_text(text)
    report=validate(dest)
    archive=out/'visual-thinking-public-preview.zip'
    if archive.exists():raise SystemExit(f'Refusing to overwrite {archive}')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(dest.rglob('*')):
            if p.is_file():z.write(p,Path('visual-thinking')/p.relative_to(dest))
    report['zip_files']=sum(1 for p in dest.rglob('*') if p.is_file());(out/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'directory':str(dest),'archive':str(archive),'validation':report},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
