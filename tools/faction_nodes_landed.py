# 生成 docs/faction_nodes_landed.xlsx（报告 391）：python3 tools/faction_nodes_landed.py . docs/faction_nodes.xlsx docs/faction_nodes_landed.xlsx
import json, os, sys, openpyxl
from openpyxl.styles import Font, PatternFill, Alignment
root = sys.argv[1]; design = sys.argv[2]; out = sys.argv[3]
names = {'pantheon':'万神院','legion':'后勤部队','cartographers':'地图协会','greylamp':'灰灯互助会','growers':'河滩垦户社','society':'魔法师协会','envoy':'边境使团','hunters':'北境猎盟'}
order = ['pantheon','legion','cartographers','greylamp','growers','society','envoy','hunters']
gods = {'brute':'蛮神','nature':'自然之神','sun':'日神','skill':'技巧之神','hunt':'狩猎之神','earth':'大地之神'}
comm = {}
for fn in os.listdir(f'{root}/data/authoring/commissions'):
    d = json.load(open(f'{root}/data/authoring/commissions/{fn}')); comm[d['id']] = d['display_name']
def text(n):
    e = n.get('effect',''); v = n.get('value')
    if n.get('placeholder'):
        if e == 'god': return f'留给{gods.get(v,v)}的位置：刻度上显示？？？？，到了也不能选'
        return '留空'
    if e == 'inquiry': return '开放调查委托和许可单'
    if e == 'finale': return '开放结案委托；办完许可单后告示栏出这一方的常规委托'
    if e == 'god': return f'可以选{gods.get(v,v)}'
    if e == 'faith_xp': return f'奉神时经验值 +{round(float(v or 0.1)*100)}%'
    if e == 'altar_bless': return '神坛上多一个【赐福】'
    if e == 'commission': return f'开放委托《{comm.get(v,v)}》'
    if e == 'alchemy_loss': return f'炼尘折损降到 {round(float(v)*100)}%'
    if e == 'canteen_pot': return f'食堂的锅变成 {v[0]}×{v[1]}'
    if e == 'canteen_store': return f'食材仓库变成 {v[0]}×{v[1]}'
    if e == 'nursery_plot': return '苗圃多一片地'
    return e
dwb = openpyxl.load_workbook(design)
wb = openpyxl.Workbook(); wb.remove(wb.active)
ws = wb.create_sheet('说明')
for line in ['阵营声望节点：实装后的样子（报告 389，按游戏数据 data/authoring/factions/*.json 生成）',
 '每页一个阵营。上半是刻度上的节点（声望到了这个数就生效）；下面是【赠礼】；再下面是还空着、等作者挑的位置。',
 '状态：已实装 = 游戏里已经是这样；占位 = 刻度上看得见、显示？？？？、到了不生效；候选（未实装）= 架构出的候选，作者在 docs/faction_nodes.xlsx 填「留 / 改」后再落。',
 '要改数或效果：改 docs/faction_nodes.xlsx（作者用的那份），执行线程照着改数据。这份只是给作者看现状，不用填。',
 '注意：常规纸条现在最多把一方推到 50 声望，剧情每方只给 25，所以各方 100 的节点眼下到不了；放不放开已发到确认清单（报告 391 第三节第 3 条）。']:
    ws.append([line])
ws.column_dimensions['A'].width = 120
head = Font(bold=True); fills = {'已实装':'D9EAD3','占位':'FFF2CC','候选（未实装）':'EFEFEF','空缺':'F4CCCC'}
for fid in order:
    f = json.load(open(f'{root}/data/authoring/factions/{fid}.json'))
    ws = wb.create_sheet(names[fid])
    ws.append(['声望','效果','种类','状态']); [setattr(c,'font',head) for c in ws[1]]
    for n in sorted(f.get('nodes',[]), key=lambda n:n['rep']):
        st = '占位' if n.get('placeholder') else '已实装'
        kind = {'open':'开放','boost':'提升'}.get(n.get('kind'),'') if n.get('effect') else ''
        ws.append([n['rep'], text(n), kind, st])
    if not f.get('listed', True):
        ws.append(['', '这一方还没开放（不在委托簿里），节点等这一方的内容做出来再写', '', '空缺'])
    ws.append([])
    ws.append(['赠礼']); ws.cell(ws.max_row,1).font = head
    ws.append([f"每 {f.get('gift_every',0)}", f"声望每攒 {f.get('gift_every',0)} 点，【赠礼】可领 +1 份，一直累积；老存档从 0 算起补发", '赠礼', '已实装'])
    pool = '；'.join(f"{g['funds']} 金币" if g.get('funds') else f"{g.get('item')} ×{g.get('count',1)}" for g in f.get('gift_pool',[]))
    ws.append(['内容', f'领的时候随机给一样。现在放的是占位：{pool}', '赠礼', '占位'])
    if names[fid] in dwb.sheetnames:
        cands = []
        gift_cand = ''
        for r in dwb[names[fid]].iter_rows(min_row=2, values_only=True):
            if r and len(r) > 3 and r[3] == '候选' and r[2] != '赠礼':
                cands.append(r)
            if r and len(r) > 3 and r[2] == '赠礼' and r[0] == '内容':
                gift_cand = str(r[1])
        if gift_cand:
            ws.append(['', gift_cand, '赠礼', '候选（未实装）'])
        if cands:
            ws.append([])
            ws.append(['空着的位置（候选，等作者挑）']); ws.cell(ws.max_row,1).font = head
            for r in cands:
                ws.append([r[0], r[1], r[2], '候选（未实装）'])
    for row in ws.iter_rows(min_row=2):
        st = row[3].value if len(row) > 3 else None
        if st in fills:
            for c in row: c.fill = PatternFill('solid', fgColor=fills[st])
        for c in row: c.alignment = Alignment(wrap_text=True, vertical='top')
    ws.column_dimensions['A'].width = 10; ws.column_dimensions['B'].width = 70; ws.column_dimensions['C'].width = 8; ws.column_dimensions['D'].width = 16
wb.save(out)
print('ok')
