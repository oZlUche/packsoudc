# 汇总 gd1032 连打：每套牌 × 背包档 × 难度：14 场胜几场、第一场输在第几场、平均用时、被消耗的东西（按出现次数）
import sys, collections
T = {-1: "空包", 0: "普通", 2: "稀有", 4: "传说"}
rows = collections.defaultdict(list)
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.startswith("GD1032 C|"): continue
    _, b, t, k, d, j, kind, w, dur, hp, tn, tv, left = line.strip().split("|")
    rows[(b, int(t), d)].append((int(k), int(j), kind, w == "W", float(dur), tn, int(tv), int(left)))
print("| 套牌 | 背包 | 难度 | 胜（共 4 套 × 14 场） | 头 3 场胜 | 后 4 场（精英 3 + 首领）胜 | 首败平均在第几场 | 平均用时 | 打完剩几件 | 被消耗的（前几名） |")
print("|---|---|---|---|---|---|---|---|---|---|")
for key in sorted(rows, key=lambda x: (x[0], x[1], x[2])):
    r = rows[key]; b, t, d = key
    wins = sum(x[3] for x in r)
    first3 = sum(x[3] for x in r if x[1] < 3); n3 = sum(1 for x in r if x[1] < 3)
    last = sum(x[3] for x in r if x[1] >= 10); nl = sum(1 for x in r if x[1] >= 10)
    fl = []
    for k in set(x[0] for x in r):
        seq = sorted((x for x in r if x[0] == k), key=lambda x: x[1])
        lost = [x[1] + 1 for x in seq if not x[3]]
        fl.append(lost[0] if lost else 15)
    endleft = [sorted((x for x in r if x[0] == k), key=lambda x: x[1])[-1][7] for k in set(x[0] for x in r)]
    eaten = collections.Counter(x[5] for x in r if x[5] != "-")
    print(f"| {b} | {T[t]} | {'A0' if d=='normal' else 'A8'} | {wins}/{len(r)} | {first3}/{n3} | {last}/{nl} | {sum(fl)/len(fl):.1f} | {sum(x[4] for x in r)/len(r):.1f} 秒 | {sum(endleft)/len(endleft):.1f} | {', '.join(f'{a}×{c}' for a, c in eaten.most_common(4))} |")
