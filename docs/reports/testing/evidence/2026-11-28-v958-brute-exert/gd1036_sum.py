# 汇总 gd1128 的 F 行：每套牌 × 背包档 × 难度 × 敌人类：胜率、平均用时、赢时剩余生命；再算「空包对传说」的差
import sys, collections, statistics
NAMES = {"sun_blaze": "日神·大日炎炎 + 日光浴 + 星移斗转", "sun_eternal": "日神·永日不落", "brute": "蛮神", "brute_exert": "蛮神 + 竭力", "skill": "技巧之神",
         "nature": "自然之神", "earth": "大地之神", "none": "无信者（对照）"}
TIERS = {-1: "空包", 0: "普通", 2: "稀有", 4: "传说"}
DIFF = {"normal": "A0", "ascension_8": "A8"}
KIND = {"normal": "普通", "elite": "精英", "boss": "首领"}
cell = collections.defaultdict(list)
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.startswith("GD1036 F|"): continue
    _, b, t, k, d, kind, i, w, dur, hp = line.strip().split("|")
    cell[(b, int(t), d, kind)].append((w == "W", float(dur), float(hp) if hp not in ("-", "") else 0.0))
def stat(rows):
    n = len(rows); wins = [r for r in rows if r[0]]
    return n, len(wins) / n if n else 0, statistics.mean(r[1] for r in rows) if rows else 0, statistics.mean(r[2] for r in wins) if wins else 0
out = []
order = [b for b in NAMES if any(key[0] == b for key in cell)]
for d in DIFF:
    out.append(f"\n### {DIFF[d]}\n")
    out.append("| 套牌 | 敌人 | 空包 | 普通 | 稀有 | 传说 | 空包 − 传说（胜率） |")
    out.append("|---|---|---|---|---|---|---|")
    for b in order:
        for kind in KIND:
            cols = []; wr = {}
            for t in TIERS:
                n, w, dur, hp = stat(cell.get((b, t, d, kind), []))
                wr[t] = w
                cols.append(f"{w*100:.0f}% · {dur:.1f} 秒 · {hp*100:.0f}%")
            out.append(f"| {NAMES[b]} | {KIND[kind]} | " + " | ".join(cols) + f" | {(wr[-1]-wr[4])*100:+.0f} |")
# 「空包对传说」：三类敌人、两档难度合起来
out.append("\n### 空包对传说（三类敌人、A0 + A8 合起来）\n")
out.append("| 套牌 | 空包胜率 | 传说胜率 | 差（点） | 空包用时 | 传说用时 | 空包赢时剩余生命 | 传说赢时剩余生命 |")
out.append("|---|---|---|---|---|---|---|---|")
for b in order:
    e = sum((cell.get((b, -1, d, k), []) for d in DIFF for k in KIND), [])
    l = sum((cell.get((b, 4, d, k), []) for d in DIFF for k in KIND), [])
    ne, we, de, he = stat(e); nl, wl, dl, hl = stat(l)
    out.append(f"| {NAMES[b]} | {we*100:.0f}% | {wl*100:.0f}% | {(wl-we)*100:.0f} | {de:.1f} 秒 | {dl:.1f} 秒 | {he*100:.0f}% | {hl*100:.0f}% |")
n = sum(len(v) for v in cell.values())
print(f"共 {n} 场；每格 {min(len(v) for v in cell.values())}–{max(len(v) for v in cell.values())} 场")
print("\n".join(out))
