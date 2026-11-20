"""报告 343：从 authoring JSON + 供给审计（probe_sources.gd.txt 的输出 sources.json）生成非战斗道具表。
用法：python3 -I docs/reports/343-noncombat-items/build_table.py <sources.json> <输出目录>
推荐用法、占位判定的人工补充在 recs.py。"""
import json, glob, os, sys, collections
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
A = os.path.join(ROOT, 'data', 'authoring')
RAR = ['普通', '优良', '稀有', '史诗', '传说', '神话']
BASE = [5, 12, 30, 75, 200]
KIND = {'material': '素材', 'valuable': '贵重品', 'keepsake': '特殊道具', 'food': '食物', 'remedy': '药品', 'trinket': '信物'}
MAT = {'metal': '金属', 'stone': '石', 'wood': '木', 'bone': '骨', 'leather': '皮', 'cloth': '布', 'clay': '陶', 'herb': '草药', 'flesh': '肉', 'gem': '宝石'}
EXCL = {'weapon', 'armor', 'shield', 'ammo', 'crystal'}
DIR_TAGS = {'mineral': '矿物', 'plant': '草木', 'beast_part': '兽材', 'crafted': '工艺', 'magic': '魔法', 'nature': '自然', 'clockwork': '机关', 'bullion': '金银', 'treasure': '珍宝', 'reagent': '药剂', 'supply': '补给'}
FAC = {'legion': '军团', 'society': '协会', 'greylamp': '灰灯', 'hunters': '猎盟', 'envoy': '使团'}


def load(d):
    return {os.path.basename(f)[:-5]: json.load(open(f, encoding='utf-8')) for f in glob.glob(os.path.join(A, d, '*.json'))}


items = load('items')
names = {k: v['display_name'] for k, v in items.items()}


def nm(i):
    return f"{names.get(i, i)}（{i}）"


def cells(d):
    return sum(r.count('1') for r in d['shape'])


def in_scope(d):
    t = d.get('tags', [])
    if any(k in t for k in EXCL):
        return False
    if any(x.startswith('faith:') for x in t) and 'trinket' in t:
        return True          # 信物（护符、种子）——charm_earth 带 is_bag 也算
    if d.get('is_bag') or 'trinket' in t:
        return False         # 其余饰物（插件、军功牌）都是上板参战的
    return True


def kind_of(d):
    t = d.get('tags', [])
    for k in ['material', 'valuable', 'keepsake', 'food', 'remedy', 'trinket']:
        if k in t:
            return KIND[k]
    if 'ticket' in t:
        return '券'
    if 'token' in t:
        return '铸牌'
    if 'commission' in t:
        return '委托物'
    return '其他'


recipes = load('recipes')
smith = load('smith_recipes')
techs = load('techs')
faiths = load('faiths')
events = load('events')
commissions = load('commissions')
tnames = {k: v['display_name'] for k, v in techs.items()}
SMITH_LEVEL = ['', '一级', '二级', '三级']


def slot_fits(slot, d):
    if (d.get('rarity') or 0) < slot['min']:
        return False
    m = slot['material']
    if m.startswith('crystal:'):
        return False
    return 'material' in d.get('tags', []) and d.get('material') == m


def smith_slots(r):
    out = [{'material': m, 'min': v, 'count': 1} for m, v in sorted((r.get('material_inputs') or {}).items())]
    out += [{'material': s['material'], 'min': s['min'], 'count': s.get('count', 1)} for s in r.get('material_slots', [])]
    return out


def uses(i, d):
    u = []
    for r in recipes.values():
        if i in r['inputs']:
            other = [x for x in r['inputs'] if x != i] or [i]
            u.append(f"局内拼合：+{names.get(other[0], other[0])} → {names.get(r['output'], r['output'])}")
    for r in smith.values():
        if i in (r.get('inputs') or {}):
            tech = f"，科技{tnames.get(r['tech'], r['tech'])}" if r.get('tech') else ''
            u.append(f"铁匠铺{SMITH_LEVEL[r.get('level', 1)]}{tech}：{names.get(r['output'], r['output'])} ×{r['inputs'][i]}")
    slot_hits = collections.Counter()
    for r in smith.values():
        for s in smith_slots(r):
            if slot_fits(s, d):
                slot_hits[(MAT[s['material']], RAR[s['min']])] += 1
    for (m, mn), n in sorted(slot_hits.items()):
        u.append(f"铁匠铺材料格「{m} ≥{mn}」（{n} 张配方）")
    for t in techs.values():
        for k, tier in enumerate(t.get('tiers', [])):
            if i in (tier.get('items') or {}):
                u.append(f"科技「{t['display_name']}」{k + 1} 级成本 ×{tier['items'][i]}")
    for e in events.values():
        s = json.dumps(e, ensure_ascii=False)
        if f'"item": "{i}"' in s and ('"lose_item"' in s or '"has_item"' in s) and e['id'] != 'tut_elite':
            if '"type": "give_item", "item": "%s"' % i in s:
                continue
            u.append(f"事件「{e['title']}」交出换钱 / 换药")
    for c in commissions.values():
        if f'"{i}"' in json.dumps(c):
            u.append(f"委托物：「{c['display_name']}」")
    if '"poxiao_token"' == f'"{i}"':
        u.append('铁匠处的特殊对话凭证（破晓）')
    return u


def gods(d):
    t = set(d.get('tags', []))
    n = cells(d)
    out = []
    for f in faiths.values():
        for r in f.get('offerings') or []:
            ok = False
            if r.get('tags') and t & set(r['tags']):
                ok = True
            if r.get('min_cells') and n >= r['min_cells']:
                ok = True
            if r.get('exact_grade', -1) >= 0:
                g = max(i for i, fl in enumerate([1, 2, 5, 9, 13]) if n >= fl)
                ok = ok or g == r['exact_grade']
            if ok:
                out.append(f['display_name'])
                break
    return out


SRC = {'search': '普通搜索', 'node:mine': '矿脉', 'node:grove': '林地', 'node:remains': '遗骸', 'node:runes': '符文堆', 'shop': '局内商店', 'enemy': '敌人携带', 'treasure': '珍宝掉落', 'chest': '宝箱'}
CH = {'free_mode': '废墟', 'clockwork_hourglass': '沙漏', 'slice_ruins': '切片'}
STALL = {'goods': '杂货铺', 'food': '粮铺', 'remedy': '药铺', 'loose': '散货摊', 'arms': '兵器铺', 'armor': '甲胄铺'}
POOLS = {k: v['display_name'] for k, v in load('reward_pools').items()}


def enemy_specific(i):
    out = []
    for e in load_enemies.values():
        for key in ('signature', 'loot_filler'):
            if f'"{i}"' in json.dumps(e.get(key, '')):
                out.append(e['display_name'])
    return sorted(set(out))


load_enemies = load('enemies')


def sources(i, d, ext):
    s = ext.get(i, [])
    by = collections.defaultdict(set)
    for e in s:
        k = e['kind']
        if k.startswith('market:'):
            by['集市'].add(STALL.get(k[7:], k[7:]))
        elif k.startswith('pool:'):
            by['事件奖励'].add(POOLS.get(k[5:], k[5:]))
        else:
            by[SRC.get(k, k)].add(CH.get(e['where'], e['where']))
    order = ['普通搜索', '矿脉', '林地', '遗骸', '符文堆', '敌人携带', '局内商店', '事件奖励', '集市', '珍宝掉落', '宝箱']
    parts = []
    for k in order:
        if k in by:
            v = sorted(by[k])
            if k in ('普通搜索', '局内商店') and len(v) == 3:
                parts.append(f"{k}（各章）")
            else:
                parts.append(f"{k}（{'、'.join(v)}）")
    sp = enemy_specific(i)
    if sp:
        parts.append(f"专属掉落：{'、'.join(sp)}")
    for r in recipes.values():
        if r['output'] == i:
            parts.append('局内拼合产出')
    for r in smith.values():
        if r['output'] == i:
            parts.append('铁匠铺冶炼')
    return parts


def main():
    ext = json.load(open(sys.argv[1], encoding='utf-8'))
    sys.path.insert(0, os.path.dirname(__file__))
    import recs
    rows = []
    for i, d in sorted(items.items()):
        if not in_scope(d):
            continue
        r = d.get('rarity') or 0
        val = d.get('value') or BASE[min(r, 4)] * cells(d)
        t = d.get('tags', [])
        u = uses(i, d)
        src = sources(i, d, ext) + recs.EXTRA_SOURCES.get(i, [])
        dirs = [DIR_TAGS[x] for x in t if x in DIR_TAGS]
        placeholder = i in recs.PLACEHOLDER
        base_use = list(dict.fromkeys(recs.EXTRA_USES.get(i, []) + u))
        if not base_use:
            base_use = ['仅可出售']
        rows.append({
            'group': recs.group_of(i, kind_of(d)),
            'id': i, 'name': d['display_name'], 'kind': kind_of(d), 'rarity': RAR[r], 'rarity_n': r,
            'value': val, 'cells': cells(d), 'material': MAT.get(d.get('material', ''), '—'),
            'tags': '、'.join(dirs) or '—', 'uses': base_use, 'gods': gods(d),
            'sources': src or ['无随机来源'], 'rec': recs.REC.get(i, ''), 'placeholder': placeholder,
        })
    json.dump(rows, open(os.path.join(sys.argv[2], 'rows.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(len(rows))


if __name__ == '__main__':
    main()


GROUP_ORDER = ['素材·矿物', '素材·草木', '素材·兽材', '素材·机关', '素材·魔法', '素材·药剂', '素材·工艺', '药品', '食物',
               '贵重品', '信物', '特殊道具', '券', '铸牌', '委托物']


def render(rows_path, md_path, xlsx_path):
    rows = json.load(open(rows_path, encoding='utf-8'))
    rows.sort(key=lambda r: (GROUP_ORDER.index(r['group']), r['rarity_n'], r['id']))
    md = []
    for g in GROUP_ORDER:
        part = [r for r in rows if r['group'] == g]
        if not part:
            continue
        md.append(f"\n### {g}（{len(part)} 件）\n")
        md.append('| 道具 | 稀有度 | 基础价 | 用途 | 出处 | 可献给 | 推荐用法 |')
        md.append('|---|---|---:|---|---|---|---|')
        for r in part:
            use = '；'.join(r['uses'])
            if r['placeholder']:
                use = '**纯占位**：' + use
            md.append(f"| {r['name']}（`{r['id']}`） | {r['rarity']} | {r['value']} | {use} | {'；'.join(r['sources'])} | "
                      f"{'、'.join(r['gods']) or '—'} | {r['rec'] or '—'} |")
    open(md_path, 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    from openpyxl import Workbook
    from openpyxl.styles import Font, Alignment, PatternFill
    wb = Workbook()
    ws = wb.active
    ws.title = '非战斗道具'
    head = ['分组', '名称', 'id', '稀有度', '基础价', '占格', '材质', '标签（倾向方向）', '用途', '纯占位', '出处', '可献给', '推荐用法']
    ws.append(head)
    for r in rows:
        ws.append([r['group'], r['name'], r['id'], r['rarity'], r['value'], r['cells'], r['material'], r['tags'],
                   '；'.join(r['uses']), '是' if r['placeholder'] else '', '；'.join(r['sources']), '、'.join(r['gods']), r['rec']])
    widths = [10, 14, 20, 7, 7, 5, 6, 16, 50, 6, 60, 22, 50]
    for i, w in enumerate(widths):
        ws.column_dimensions[chr(65 + i)].width = w
    for c in ws[1]:
        c.font = Font(bold=True)
    fill = PatternFill('solid', fgColor='FCE4D6')
    for row in ws.iter_rows(min_row=2):
        for c in row:
            c.alignment = Alignment(wrap_text=True, vertical='top')
        if row[9].value == '是':
            for c in row:
                c.fill = fill
    ws.freeze_panes = 'C2'
    ws.auto_filter.ref = ws.dimensions
    wb.save(xlsx_path)
