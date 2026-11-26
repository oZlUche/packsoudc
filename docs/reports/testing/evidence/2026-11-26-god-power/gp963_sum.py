import sys, statistics as st, collections
NAMES = {"brute": "蛮神", "sun": "日神", "nature": "自然之神", "skill": "技巧之神", "": "无信者"}
RAR = {0: "普通", 2: "稀有", 4: "传说"}
def load(path):
    runs, cps, loo = [], [], []
    for line in open(path, encoding="utf-8"):
        if not line.startswith("GP963 "): continue
        f = line.strip().split("|")
        tag = f[0][6:]
        if tag == "RUN":
            d = dict(god=f[1], rar=int(f[2]), r=int(f[3]), kit=f[4][4:], wins=f[5][5:])
            for x in f[6:]:
                k, v = x.split(" "); d[k] = float(v)
            runs.append(d)
        elif tag == "CP":
            d = dict(god=f[1], rar=int(f[2]), r=int(f[3]), L=int(f[4][1:]))
            for x in f[7:]:
                k, v = x.split(" "); d[k] = float(v)
            d["dps"] = float(f[5].split(" ")[1].split("/")[0])
            cps.append(d)
        elif tag == "LOO":
            for x in f[4].split(";"):
                cid, v = x.split("=")
                a, b = v.split("/")
                loo.append(dict(god=f[1], rar=int(f[2]), r=int(f[3]), cid=cid, d=float(a), m=float(b)))
    return runs, cps, loo
def pct(x): return "%.0f%%" % (100 * x)
def table(path, title):
    runs, cps, loo = load(path)
    out = ["### " + title, "", "| 组 | 局数 | 胜场 | 伤害：中位 / 最高 | 挡下或回复：中位 / 最高 | 30 级伤害：中位 / 最高 | 30 级挡下或回复：中位 / 最高 | 每秒伤害（全开） |", "|---|---|---|---|---|---|---|---|"]
    groups = collections.OrderedDict()
    for d in runs: groups.setdefault((d["god"], d["rar"]), []).append(d)
    for (g, r), ds in groups.items():
        l30 = [c for c in cps if c["god"] == g and c["rar"] == r and c["L"] == 30]
        w = sum(int(d["wins"].split("/")[0]) for d in ds); n = sum(int(d["wins"].split("/")[1]) for d in ds)
        def mm(xs): return "%s / %s" % (pct(st.median(xs)), pct(max(xs))) if xs else "—"
        if g == "":
            out.append("| %s·%s | %d | %d/%d | — | — | — | — | %.1f |" % (NAMES[g], RAR[r], len(ds), w, n, st.median([d["dps"] for d in ds])))
            continue
        out.append("| %s·%s | %d | %d/%d | %s | %s | %s | %s | %.1f |" % (NAMES[g], RAR[r], len(ds), w, n,
            mm([d["god_d"] for d in ds]), mm([d["god_m"] for d in ds]), mm([c["god_d"] for c in l30]), mm([c["god_m"] for c in l30]),
            st.median([d["dps"] for d in ds])))
    out.append("")
    # over-60 runs at L30 and their top cards
    over = [c for c in cps if c["L"] == 30 and c["god"] and (c["god_d"] > 0.6 or c["god_m"] > 0.6)]
    out.append("30 级超过六成的局：%d / %d" % (len(over), len([c for c in cps if c["L"] == 30 and c["god"]])))
    out.append("")
    for c in over:
        mine = sorted([x for x in loo if x["god"] == c["god"] and x["rar"] == c["rar"] and x["r"] == c["r"]], key=lambda x: -max(x["d"], x["m"]))[:4]
        out.append("- %s·%s 第 %d 局：伤害 %s，挡下或回复 %s；拿掉一张掉得最多：%s" % (NAMES[c["god"]], RAR[c["rar"]], c["r"], pct(c["god_d"]), pct(c["god_m"]),
            "，".join("%s（伤害 -%s / 防 -%s）" % (x["cid"], pct(x["d"]), pct(x["m"])) for x in mine)))
    out.append("")
    # per card average marginal across runs where taken
    out.append("| 神 | 牌 | 拿到的局数 | 拿掉它伤害平均少 | 最多少 | 挡下或回复平均少 | 最多少 |")
    out.append("|---|---|---|---|---|---|---|")
    by = collections.defaultdict(list)
    for x in loo: by[(x["god"], x["cid"])].append(x)
    rows = sorted(by.items(), key=lambda kv: -max(st.mean([x["d"] for x in kv[1]]), st.mean([x["m"] for x in kv[1]])))
    for (g, cid), xs in rows[:25]:
        out.append("| %s | %s | %d | %s | %s | %s | %s |" % (NAMES[g], cid, len(xs), pct(st.mean([x["d"] for x in xs])), pct(max(x["d"] for x in xs)),
            pct(st.mean([x["m"] for x in xs])), pct(max(x["m"] for x in xs))))
    return "\n".join(out)
if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(table(p, p)); print()
