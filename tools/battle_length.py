#!/usr/bin/env python3
"""报告 388 第二节：战斗时长对比表。

两步，配合 tools/bench_matrix.gd 的频率测试（真地图上的战斗点）：

1. 造三位角色的木桩：把流派木桩的基线换成每位角色 json 里的 base_stats（只换生命、耐力、回复；被动技能木桩本来就不带）

    python3 tools/battle_length.py dummies data/authoring/calibration/archetypes.json <输出.json>

2. 跑频率测试（A0 = normal 难度）后出表

    godot --headless --path . --script res://tools/bench_matrix.gd -- <输出.json> standard_ruins normal 20 1 --mode=frequency --maps=20 --out-dir=<目录>
    python3 tools/battle_length.py table <目录>/exp-*/cases.jsonl [--label=名字] [--json=<汇总.json>]

只看「同段同档」（木桩的段 = 敌人的档）的场次，按节点类型分：battle = 普通，elite = 精英，core = 首领。
耐力打空 = 这一场我方至少有一次冷却走完、付不起消耗没出手（ITEM_SKIPPED）。
"""
import json
import statistics
import sys
from collections import defaultdict

CHARS = ["andreus", "marcus", "brutus"]
NAMES = {"battle": "普通", "elite": "精英", "core": "首领", "andreus": "安德鲁斯", "marcus": "马库斯", "brutus": "布鲁图斯"}
OVERTIME = 30.0


def make_dummies(src, out):
    with open(src, encoding="utf-8") as f:
        base = json.load(f)
    res = {}
    for c in CHARS:
        with open("data/authoring/characters/%s.json" % c, encoding="utf-8") as f:
            stats = json.load(f)["base_stats"]
        for k, d in base.items():
            nd = dict(d)
            nd["baseline"] = {key: float(v) for key, v in stats.items()}
            nd["hp"] = float(stats["max_hp"])
            nd["archetype"] = "%s@%s" % (d.get("archetype", "real"), c)
            nd["character"] = c
            res["%s@%s" % (k, c)] = nd
    with open(out, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print("写入 %s：%d 份" % (out, len(res)))


def pct(xs, q):
    xs = sorted(xs)
    if not xs:
        return float("nan")
    i = min(len(xs) - 1, max(0, int(round(q * (len(xs) - 1)))))
    return xs[i]


def load(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            if not r.get("valid") or r.get("bracket") != r.get("tier"):
                continue
            rows.append(r)
    return rows


def summarize(rows):
    by_type = defaultdict(list)
    by_char = defaultdict(list)
    by_char_type = defaultdict(list)
    for r in rows:
        t = (r.get("node") or {}).get("type", "?")
        c = r["archetype"].split("@")[-1] if "@" in r["archetype"] else r.get("character", "")
        by_type[t].append(r)
        by_char[c].append(r)
        by_char_type[(c, t)].append(r)

    def stat(rs):
        d = [float(r["duration"]) for r in rs]
        wins = [r for r in rs if r.get("outcome") == "win"]
        sk = [r for r in rs if (r["metrics"].get("skipped") or [0, 0])[0] > 0]
        foe_sk = [r for r in rs if (r["metrics"].get("skipped") or [0, 0])[1] > 0]
        won_d = [float(r["duration"]) for r in wins]
        fs = [float(r["metrics"]["first_skip"][0]) for r in sk if r["metrics"].get("first_skip", [None])[0] is not None]
        return {
            "n": len(rs), "win": len(wins) / len(rs) if rs else 0.0,
            "mean": statistics.fmean(d) if d else 0.0, "median": statistics.median(d) if d else 0.0,
            "p10": pct(d, 0.1), "p90": pct(d, 0.9),
            "overtime": sum(1 for x in d if x > OVERTIME) / len(d) if d else 0.0,
            "skip_share": len(sk) / len(rs) if rs else 0.0,
            "foe_skip_share": len(foe_sk) / len(rs) if rs else 0.0,
            "win_median": statistics.median(won_d) if won_d else 0.0,
            "skips": statistics.fmean([(r["metrics"].get("skipped") or [0, 0])[0] for r in rs]) if rs else 0.0,
            "first_skip": statistics.median(fs) if fs else None,
            "hp_left": statistics.fmean([float(r["hp_end"][0]) for r in wins]) if wins else 0.0,
        }

    return {
        "type": {t: stat(v) for t, v in by_type.items()},
        "char": {c: stat(v) for c, v in by_char.items()},
        "char_type": {"%s/%s" % k: stat(v) for k, v in by_char_type.items()},
    }


def table(path, label, json_out):
    s = summarize(load(path))
    print("### %s\n" % label)
    print("| 节点 | 场数 | 胜率 | 平均时长 | 中位 | 10%~90% | 赢的场中位 | 过 30 秒 | 我方耐力打空 | 敌方耐力打空 | 我方每场没出手 | 赢时余血 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for t in ["battle", "elite", "core"]:
        if t not in s["type"]:
            continue
        x = s["type"][t]
        print("| %s | %d | %.0f%% | %.1f 秒 | %.1f 秒 | %.1f~%.1f | %.1f 秒 | %.0f%% | %.0f%% | %.0f%% | %.1f | %.0f%% |" % (
            NAMES[t], x["n"], x["win"] * 100, x["mean"], x["median"], x["p10"], x["p90"], x["win_median"], x["overtime"] * 100,
            x["skip_share"] * 100, x["foe_skip_share"] * 100, x["skips"], x["hp_left"] * 100))
    print("\n| 角色 | 普通胜率 | 精英胜率 | 首领胜率 | 全部胜率 | 平均时长 | 耐力打空的场 |")
    print("|---|---|---|---|---|---|---|")
    for c in CHARS:
        if c not in s["char"]:
            continue
        x = s["char"][c]
        cells = []
        for t in ["battle", "elite", "core"]:
            y = s["char_type"].get("%s/%s" % (c, t))
            cells.append("%.0f%%" % (y["win"] * 100) if y else "—")
        print("| %s | %s | %.0f%% | %.1f 秒 | %.0f%% |" % (NAMES[c], " | ".join(cells), x["win"] * 100, x["mean"], x["skip_share"] * 100))
    print()
    if json_out:
        with open(json_out, "w", encoding="utf-8") as f:
            json.dump(s, f, ensure_ascii=False, indent=1)


def main(argv):
    if len(argv) >= 3 and argv[0] == "dummies":
        make_dummies(argv[1], argv[2])
        return 0
    if len(argv) >= 2 and argv[0] == "table":
        opts = dict(a[2:].split("=", 1) for a in argv[2:] if a.startswith("--") and "=" in a)
        table(argv[1], opts.get("label", argv[1]), opts.get("json"))
        return 0
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
