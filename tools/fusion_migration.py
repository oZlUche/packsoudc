#!/usr/bin/env python3
"""合成与锻造改造 B 批（方案 docs/plans/2026-11-11-fusion-and-forging-reform.md §4.3 / §5 / §7）：
读 tools/weapon_web_tables.py 生成的附表（recipes.csv、weapons.csv、materials_all.csv），出三张清单 + 一份门禁检查。只读，不改内容。

    godot --headless --path . --script res://tools/export_weapon_web.gd -- /tmp/web.json
    python3 tools/weapon_web_tables.py /tmp/web.json /tmp/web
    python3 tools/fusion_migration.py /tmp/web <输出目录>

产出：
- migration_manifest.csv  82 条旧升级逐条处置（方案 §4.3 的字段）
- gold18_sources.csv      18 件 forged_only 金武的新来源、需求（家族 / 最低稀有度 / 件数分开写）、资金、解锁、候选数
- smith_migration.csv     现有打造配方里吃「上一把武器」的（方案 §5.2），及其建议
- checks.md               门禁：无遗漏、无把门槛当数量、无无意断供、每条需求有候选

所有「建议初值」是给作者 / 架构设计看的起点，不是定案；C 批实现前按回音改这里的常量再重跑。
"""
import csv
import os
import re
import sys

MANIFEST_VERSION = 1

RARITY = ["白", "绿", "蓝", "紫", "金", "红"]

# 方案 §4.2：首轮局内限定合成候选（两件具体输入；成品从此不走打造）
FUSION_ONLY = {
    "flame_fang": ("bloodbone_spike", "fire_crystal"),
    "frost_fang": ("bloodbone_spike", "ice_crystal"),
    "thunder_heavy_crossbow": ("heavy_crossbow", "lightning_crystal"),
}
# 方案 §4.2：另加合成候选、原来的合法随机来源照旧保留的
FUSION_EXTRA = {
    "bloodletter": ("cleaver", "beast_fang"),
    "horn_bow": ("shortbow", "antler"),
    "heavy_crossbow": ("steel_crossbow", "hardwood_plank"),
}
# 建议初值：直接材料打造的金武 —— 原升级里那颗魔晶石（同族、门槛不变，1 件）+ 成品自己的材料 ≥ 蓝 2 件
FORGE_BASE_MIN = 2
FORGE_BASE_COUNT = 2
FORGE_FUNDS = 300
FORGE_LEVEL = 3
# 帝国佩剑：原升级是秘银剑 + 金属 ≥ 金；改为 金属 ≥ 金 1 件 + 金属 ≥ 紫 1 件（不吃秘银剑）
IMPERIAL = [("metal", 4, 1), ("metal", 3, 1)]


def load(path):
    with open(path, encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    if not rows:
        return
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def parse_pred(text):
    """「crystal:fire≥紫」→ ("crystal:fire", 3)；门槛是最低稀有度，不是件数"""
    m = re.match(r"^(.+?)≥(.+)$", text.strip())
    if not m:
        return None
    return m.group(1), RARITY.index(m.group(2))


def need_text(needs):
    return " + ".join("%s ≥%s ×%d" % (fam, RARITY[r], n) for fam, r, n in needs)


def candidates(materials, fam, min_r):
    out = []
    for m in materials:
        family = ("crystal:" + m["crystal_family"]) if m["crystal_family"] not in ("", "null") else m["material"]
        if family == fam and int(m["rarity"]) >= min_r and m["in_random_pool"] == "True":
            out.append(m["item_id"])
    return out


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    recipes = load(os.path.join(src, "recipes.csv"))
    weapons = {w["item_id"]: w for w in load(os.path.join(src, "weapons.csv"))}
    materials = load(os.path.join(src, "materials_all.csv"))
    upgrades = [r for r in recipes if r["kind"].startswith("升级")]
    gold = sorted(k for k, w in weapons.items() if w["forged_only"] == "True")

    manifest = []
    for r in upgrades:
        o = r["output"]
        w = weapons.get(o, {})
        channels = w.get("channels_by_rule", "").strip()
        if o in FUSION_ONLY:
            disp, entry, new_id = "替换合成（局内限定）", "相邻合成：%s + %s" % FUSION_ONLY[o], "fuse_" + o
        elif w.get("forged_only") == "True":
            disp, entry, new_id = "改为材料打造", "基地铁匠铺", "forge_" + o
        elif o in FUSION_EXTRA:
            disp, entry, new_id = "保留其他来源并停用；另加合成候选", "相邻合成：%s + %s；原随机来源" % FUSION_EXTRA[o], "fuse_" + o
        else:
            disp, entry, new_id = "保留其他来源并停用", "原随机来源", ""
        manifest.append({
            "manifest_version": MANIFEST_VERSION,
            "old_recipe_id": r["recipe_id"],
            "inputs": r["inputs"],
            "material_threshold": r["material_predicates"],
            "funds": r["funds"],
            "smith_level": r["smith_level"],
            "tech": r["tech"],
            "output": o,
            "output_name": w.get("name_zh", ""),
            "output_rarity": r["output_rarity"],
            "disposition": disp,
            "new_entry": entry,
            "new_recipe_id": new_id,
            "unlock": ("铁匠铺 %d 级" % FORGE_LEVEL) if new_id.startswith("forge_") else "",
            "old_id_compat": "旧 recipe_id 不再被任何入口读；武器 id、图、存档实例不变",
            "evidence": channels if channels else "无随机来源（仅制造）",
        })

    gold_rows = []
    by_out = {}
    for m in manifest:
        by_out.setdefault(m["output"], []).append(m)
    for o in gold:
        w = weapons[o]
        olds = by_out.get(o, [])
        if o in FUSION_ONLY:
            a, b = FUSION_ONLY[o]
            needs, route, rid, funds, unlock = [], "局内合成限定", "fuse_" + o, "", "首次合成即发现"
            in_pool = {m["item_id"] for m in materials if m["in_random_pool"] == "True"}
            cand = "%s：%s；%s：%s" % (a, weapons.get(a, {}).get("channels_by_rule", "") or "仅制造 / 合成", b, "随机池" if b in in_pool else "不在随机池")
        elif o == "imperial_sword":
            needs, route, rid, funds, unlock = IMPERIAL, "材料打造", "forge_" + o, str(FORGE_FUNDS), "铁匠铺 %d 级" % FORGE_LEVEL
            cand = "; ".join("%s≥%s：%s" % (f, RARITY[r], ",".join(candidates(materials, f, r))) for f, r, _ in needs)
        else:
            pred = parse_pred(olds[0]["material_threshold"]) if olds else None
            needs = ([(pred[0], pred[1], 1)] if pred else []) + [(w["material"], FORGE_BASE_MIN, FORGE_BASE_COUNT)]
            route, rid, funds, unlock = "材料打造", "forge_" + o, str(FORGE_FUNDS), "铁匠铺 %d 级" % FORGE_LEVEL
            cand = "; ".join("%s≥%s：%s" % (f, RARITY[r], ",".join(candidates(materials, f, r))) for f, r, _ in needs)
        gold_rows.append({
            "output": o, "name_zh": w["name_zh"], "material": w["material"],
            "old_upgrade": "; ".join("%s（%s + %s）" % (m["old_recipe_id"], m["inputs"], m["material_threshold"]) for m in olds),
            "route": route, "new_recipe_id": rid,
            "needs": need_text(needs) if needs else "两件具体输入（见 new_recipe_id）",
            "funds": funds, "unlock": unlock, "candidates": cand,
            "quality": "固定 0（高档材料只满足资格，不升品质）",
        })

    smith_rows = []
    for r in recipes:
        if not r["kind"].startswith("打造"):
            continue
        ins = [p.split("×")[0] for p in r["inputs"].split(" + ") if p]
        prev = [i for i in ins if i in weapons]
        if prev:
            smith_rows.append({
                "recipe_id": r["recipe_id"], "inputs": r["inputs"], "output": r["output"],
                "consumes_weapon": ",".join(prev),
                "suggestion": "去掉前驱武器；改为其余材料 + 同档材料补足（C 批随泛材料数量一起改）",
            })

    # ---- 门禁 ----
    lines = ["# B 批门禁检查（清单版本 %d）" % MANIFEST_VERSION, ""]
    ok = True
    def check(cond, text):
        nonlocal ok
        ok = ok and cond
        lines.append("- %s %s" % ("✓" if cond else "✗", text))
    check(len(upgrades) == 82, "旧升级 %d 条（调查 304 是 82）" % len(upgrades))
    check(all(m["disposition"] for m in manifest), "82 条逐条有处置")
    check(len(gold) == 18, "forged_only 金武 %d 件（调查 304 是 18）" % len(gold))
    check(all(g["new_recipe_id"] for g in gold_rows), "18 件逐件有新来源")
    lost = [m["output"] for m in manifest if m["disposition"] == "保留其他来源并停用" and m["evidence"].startswith("无随机来源")]
    check(not lost, "停用旧升级后没有成品断供%s" % ("" if not lost else "：" + ",".join(lost)))
    empty = [g["output"] for g in gold_rows if g["route"] == "材料打造" and any(seg.endswith("：") for seg in g["candidates"].split("; "))]
    check(not empty, "每条打造需求的每一格都有随机池里的合格材料%s" % ("" if not empty else "：" + ",".join(empty)))
    check(all("×" in g["needs"] or g["route"] != "材料打造" for g in gold_rows), "需求把件数单列（×N），门槛（≥稀有度）不兼作件数")
    check(not smith_rows or all(s["consumes_weapon"] for s in smith_rows), "吃前驱武器的打造配方 %d 张已列出（方案 §5.2）" % len(smith_rows))
    lines.append("")
    lines.append("合计：%s" % ("全部通过" if ok else "有不通过"))

    write_csv(os.path.join(out, "migration_manifest.csv"), manifest)
    write_csv(os.path.join(out, "gold18_sources.csv"), gold_rows)
    write_csv(os.path.join(out, "smith_migration.csv"), smith_rows)
    with open(os.path.join(out, "checks.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
