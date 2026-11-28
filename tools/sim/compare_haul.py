# 404：对比两份 encumbrance_sim 的输出（改动前 / 改动后），按难度出带回价值表。
#   python3 tools/sim/compare_haul.py before.jsonl after.jsonl
import json,sys,collections
def load(p):
    rows=[json.loads(l) for l in open(p)]
    g=collections.defaultdict(list)
    for r in rows: g[r['difficulty']].append(r)
    return g
b=load(sys.argv[1]); a=load(sys.argv[2])
def stats(rs):
    loot=[r.get('score_parts',{}).get('loot',0) for r in rs]
    board=[sum(it[6] for it in r['items']) for r in rs]
    ext=sum(1 for r in rs if r.get('outcome')=='extracted')
    elites=sum(r['nodes'].get('elite',0) for r in rs)
    return sum(loot)/len(rs), sum(board)/len(rs), ext, len(rs), elites/len(rs)
print("| 难度 | 局数 | 撤离局 前/后 | 每局打的精英 | 带回价值（战利分）前 | 后 | 变化 | 撤离时棋盘价值 前 | 后 | 变化 |")
print("|---|---|---|---|---|---|---|---|---|---|")
tb=ta=0;bb=ba=0;n=0
for d in ['normal','ascension_4','ascension_8','ascension_12']:
    if d not in b or d not in a: continue
    sb=stats(b[d]); sa=stats(a[d])
    print(f"| {d} | {sb[3]} | {sb[2]} / {sa[2]} | {sb[4]:.1f} | {sb[0]:.0f} | {sa[0]:.0f} | {100*(sa[0]/sb[0]-1):+.1f}% | {sb[1]:.0f} | {sa[1]:.0f} | {100*(sa[1]/sb[1]-1):+.1f}% |")
    tb+=sb[0]*sb[3];ta+=sa[0]*sa[3];bb+=sb[1]*sb[3];ba+=sa[1]*sa[3];n+=sb[3]
print(f"| 合计 | {n} | | | {tb/n:.0f} | {ta/n:.0f} | {100*(ta/tb-1):+.1f}% | {bb/n:.0f} | {ba/n:.0f} | {100*(ba/bb-1):+.1f}% |")
