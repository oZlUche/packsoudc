#!/usr/bin/env python3
"""304 调查附表：读 tools/export_weapon_web.gd 的导出 JSON + data/authoring 原始作者数据，生成 CSV / Markdown 附表。只读，不改内容。

    godot --headless --path . --script res://tools/export_weapon_web.gd -- /tmp/web.json
    python3 tools/weapon_web_tables.py /tmp/web.json docs/reports/research/evidence/2026-11-11-weapon-fusion

口径（报告 §2 同）：
- 武器 = 带 `weapon` 标签的道具，排除赐福异体（`blessed_of` 非空，运行时由信仰生成，不是作者条目）。
- 配方关系按完整输入集合记一行（A + B → C 不拆成两条）；泛材质槽保留谓词，合格候选另表。
- 渠道列只说「规则上能进哪个候选池」，不是掉率实测；作者数据里按 id 点名的引用另列（引用索引），引用不等于玩家可达。
"""
import csv
import json
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTH = os.path.join(ROOT, "data", "authoring")
RARITY = ["白", "绿", "蓝", "紫", "金", "红"]
# 从代码抄的规则常量（出处见报告 §5.1）；改了代码要跟着改
MARKET_CAP_PER_LEVEL = None     # 读 base_rules/market.json
SKIP_REF_DIRS = {"items", "recipes", "smith_recipes", "tags", "help_pages", "ui", "coach", "calibration", "balance"}


def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def walk_strings(o, out):
    if isinstance(o, str):
        out.add(o)
    elif isinstance(o, dict):
        for k, v in o.items():
            out.add(k)
            walk_strings(v, out)
    elif isinstance(o, list):
        for v in o:
            walk_strings(v, out)


def ref_index(ids):
    """data/authoring 里（除道具 / 配方本身和说明类目录）按 id 点名引用的位置：id -> [目录/文件]"""
    refs = defaultdict(list)
    for d in sorted(os.listdir(AUTH)):
        full = os.path.join(AUTH, d)
        if not os.path.isdir(full) or d in SKIP_REF_DIRS:
            continue
        for root, _, files in os.walk(full):
            for fn in sorted(files):
                if not fn.endswith(".json"):
                    continue
                p = os.path.join(root, fn)
                s = set()
                walk_strings(load(p), s)
                for x in s & ids:
                    refs[x].append(os.path.relpath(p, AUTH)[:-5])
    return refs


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    doc = load(src)
    items = {i["id"]: i for i in doc["items"] if not i.get("blessed_of")}
    blessed = [i for i in doc["items"] if i.get("blessed_of")]
    weapons = {k: v for k, v in items.items() if "weapon" in v["tags"]}
    recipes = doc["recipes"]
    smith = doc["smith_recipes"]
    market = load(os.path.join(AUTH, "base_rules", "market.json"))
    econ = load(os.path.join(AUTH, "economy_rules", "standard.json"))
    node = load(os.path.join(AUTH, "node_rules", "standard.json"))
    search_ex = set(node.get("search", {}).get("exclude_tags", []))
    search_w = node.get("search", {}).get("rarity_weights", [])
    shop_ex = set(econ.get("shop_exclude_tags", []))
    shop_w = econ.get("shop_rarity_weights", [])
    pools = {}
    for fn in sorted(os.listdir(os.path.join(AUTH, "enemy_pools"))):
        p = load(os.path.join(AUTH, "enemy_pools", fn))
        pools[fn[:-5]] = [t.get("weapon_rarity_cap", -1) for t in p.get("tiers", [])]
    max_enemy_weapon_cap = max(c for caps in pools.values() for c in caps)

    # —— 配方关系（一行一张，完整输入集合）——
    rel = []
    for r in recipes:
        rel.append({"recipe_id": r["id"], "kind": "相邻拼接" if r["adjacent"] else "拖上去合（局内）",
                    "entry": "棋盘相邻 + 点接缝小锤（Fusion）" if r["adjacent"] else "拖到另一件上（CraftingModule.craft）",
                    "inputs": " + ".join(r["inputs"]), "material_predicates": "", "output": r["output"],
                    "funds": None, "smith_level": None, "tech": None, "consumes": "两件都消耗"})
    for s in smith:
        if s["is_upgrade"]:
            kind = "升级（局内砧 / 局外铁匠铺同表）"
            entry = "休息点砧（每点免费一次）+ 基地铁匠铺（付钱）"
        elif s["group"] == "smelt":
            kind, entry = "冶炼（铁匠铺）", "基地铁匠铺"
        else:
            kind, entry = "打造（铁匠铺）", "基地铁匠铺"
        rel.append({"recipe_id": s["id"], "kind": kind, "entry": entry,
                    "inputs": " + ".join("%s×%s" % (k, v) for k, v in sorted(s["inputs"].items())),
                    "material_predicates": " + ".join("%s≥%s" % (k, RARITY[int(v)]) for k, v in sorted(s["material_inputs"].items())),
                    "output": s["output"], "funds": s["funds"], "smith_level": s["level"],
                    "tech": ("%s Lv%d" % (s["tech"], s["tech_level"])) if s["tech"] else "", "consumes": "全部输入消耗"})
    for r in rel:
        ins = [x.split("×")[0] for x in r["inputs"].split(" + ") if x]
        r["inputs_missing"] = ",".join(x for x in ins if x not in items)
        r["output_missing"] = "" if r["output"] in items else r["output"]
        r["output_rarity"] = RARITY[items[r["output"]]["rarity"]] if r["output"] in items else None
        r["output_is_weapon"] = r["output"] in weapons
    write_csv(os.path.join(out_dir, "recipes.csv"), rel)

    # 泛材质谓词 → 合格候选
    preds = sorted({k for s in smith for k in s["material_inputs"]} )
    cand_rows = []
    for s in smith:
        for k, v in sorted(s["material_inputs"].items()):
            pass
    for key in preds:
        for min_r in sorted({int(s["material_inputs"][key]) for s in smith if key in s["material_inputs"]}):
            fits = []
            for i in items.values():
                if i["rarity"] < min_r:
                    continue
                if key.startswith("crystal:"):
                    ok = "crystal" in i["tags"] and i["crystal_family"] == key.split(":", 1)[1]
                else:
                    ok = "material" in i["tags"] and i["material"] == key
                if ok:
                    fits.append(i)
            cand_rows.append({"predicate": "%s≥%s" % (key, RARITY[min_r]), "candidate_count": len(fits),
                              "candidates": "; ".join("%s(%s %s%s)" % (i["id"], i["name_zh"], RARITY[i["rarity"]], "" if i["in_random_pool"] else " 不在随机池") for i in sorted(fits, key=lambda x: (x["rarity"], x["id"])))})
    write_csv(os.path.join(out_dir, "material_predicates.csv"), cand_rows)

    # —— 图：武器之间的边（输入武器 → 输出），带配方 id ——
    as_input = defaultdict(list)
    as_output = defaultdict(list)
    for r in rel:
        for x in r["inputs"].split(" + "):
            x = x.split("×")[0]
            if x:
                as_input[x].append(r["recipe_id"])
        as_output[r["output"]].append(r["recipe_id"])
    by_id = {r["recipe_id"]: r for r in rel}

    refs = ref_index(set(items))

    def channels(i):
        ch = []
        pool = i["in_random_pool"]
        r = i["rarity"]
        if pool and not (set(i["tags"]) & search_ex) and "bullion" not in i["tags"] and r < len(search_w) and search_w[r] > 0:
            ch.append("搜索池")
        if pool and not (set(i["tags"]) & shop_ex) and not i["is_bag"] and r < len(shop_w) and shop_w[r] > 0:
            ch.append("局内商店池")
        if pool and "weapon" in i["tags"] and not (set(i["tags"]) & set(market["excluded_tags"])) and i["id"] not in market["excluded_ids"]:
            caps = market["rarity_cap_per_level"]
            if r <= max(caps):
                ch.append("集市兵器摊(≥%d级)" % (next(n for n, c in enumerate(caps) if r <= c) + 1))
            lw = market["loose_rarity_weights"]
            if r < len(lw) and lw[r] > 0:
                ch.append("集市散货摊")
        if pool and "weapon" in i["tags"] and "extreme" not in i["tags"] and r <= max_enemy_weapon_cap:
            ch.append("敌人携带池(武器档≤%d)" % max_enemy_weapon_cap)
        if pool and r == 4 and not any(x["rarity"] == 4 and x["in_random_pool"] and "treasure" in x["tags"] for x in items.values()):
            ch.append("BOSS 金色保底候选")     # drop_resolver.rarity_guarantee：本档有 treasure 件时只抽 treasure
        if i["unique"] or i["lesser"]:
            ch.append("RedSources 专属来路")
        if as_output.get(i["id"]):
            ch.append("配方产出")
        return ch

    def role(iid):
        rs = []
        ins = [by_id[x]["kind"] for x in as_input.get(iid, [])]
        outs = [by_id[x]["kind"] for x in as_output.get(iid, [])]
        if any(k.startswith("相邻") for k in ins):
            rs.append("拼接输入")
        if any(k.startswith("相邻") for k in outs):
            rs.append("拼接成品")
        if any(k.startswith("升级") for k in ins):
            rs.append("升级输入")
        if any(k.startswith("升级") for k in outs):
            rs.append("升级成品")
        if any(k.startswith("打造") for k in outs):
            rs.append("铁匠打造成品")
        if any(k.startswith("打造") or k.startswith("冶炼") for k in ins):
            rs.append("打造/冶炼输入")
        if any(k.startswith("拖上去") for k in ins + outs):
            rs.append("拖合")
        return rs or ["无配方关系"]

    def combat(i):
        c = i.get("combat")
        if not c:
            return None, None, None, None, ""
        dmg = c["base_stats"].get("damage")
        cds, sts, extra = [], [], []
        for rule in c["rules"]:
            cad = rule.get("cadence") or {}
            if cad.get("class") == "CooldownCadence":
                cds.append(cad.get("seconds"))
            elif cad:
                cds.append("%s(step %s)" % (cad.get("class"), cad.get("step_seconds")))
            for cost in rule["costs"]:
                if cost["class"] == "ResourceCost":
                    sts.append("%s %s" % (cost.get("amount"), cost.get("resource_key")))
                else:
                    sts.append(cost["class"])
            for e in rule["effects"]:
                if e["class"] != "DealDamage":
                    extra.append("%s:%s" % (rule["trigger"], e["class"] + ("(%s×%s)" % (e.get("buff"), e.get("stacks")) if e.get("buff") else "") + ("(%s %s)" % (e.get("axis"), e.get("delta")) if e.get("axis") else "")))
        per_hit = any(r["trigger"] == "OnSchedule" and any(e["class"] != "DealDamage" for e in r["effects"]) for r in c["rules"])
        return dmg, " / ".join(str(x) for x in cds) or None, " / ".join(sts) or None, per_hit, "; ".join(extra)

    art = load(os.path.join(ROOT, "assets", "items", "manifest.json")) if os.path.exists(os.path.join(ROOT, "assets", "items", "manifest.json")) else {}
    art_ids = set(art.keys()) if isinstance(art, dict) else set()

    wrows = []
    for wid in sorted(weapons, key=lambda k: (weapons[k]["rarity"], k)):
        i = weapons[wid]
        dmg, cd, st, per_hit, extra = combat(i)
        cls = [t for t in i["tags"] if t in ("dagger", "one_hand", "dual", "polearm", "two_hand", "ranged", "staff")]
        wrows.append({
            "item_id": wid, "name_zh": i["name_zh"], "name_en": i["name_en"], "class_tags": ",".join(cls),
            "rarity": i["rarity"], "color": RARITY[i["rarity"]], "tags": ",".join(i["tags"]), "material": i["material"] or None,
            "unique": i["unique"], "lesser": i["lesser"], "no_random_source": i.get("no_random_source", i.get("forged_only")), "requires_unlock": i["requires_unlock"] or None,
            "cells": len(i["cells"]), "shape": json.dumps(i["cells"]), "weight": i["weight"], "value": i["value"],
            "damage_base": dmg, "cooldown_s": cd, "costs": st, "per_hit_extra": per_hit, "other_effects": extra,
            "applies": json.dumps(i["applies"], ensure_ascii=False) if i["applies"] else "",
            "has_wear": i["has_wear"], "has_description": i["has_description"],
            "art_png": os.path.exists(os.path.join(ROOT, "assets", "items", wid + ".png")),
            "in_random_pool": i["in_random_pool"], "channels_by_rule": "; ".join(channels(i)),
            "named_refs": "; ".join(refs.get(wid, [])),
            "roles": ",".join(role(wid)), "recipes_as_input": ",".join(as_input.get(wid, [])),
            "recipes_as_output": ",".join(as_output.get(wid, [])),
            "relation_count": len(as_input.get(wid, [])) + len(as_output.get(wid, [])),
        })
    write_csv(os.path.join(out_dir, "weapons.csv"), wrows)

    # 相关非武器道具：配方点名的、谓词候选的、任务引用的
    related = set()
    for r in rel:
        for x in r["inputs"].split(" + "):
            x = x.split("×")[0]
            if x and x not in weapons:
                related.add(x)
        if r["output"] not in weapons:
            related.add(r["output"])
    for row in cand_rows:
        for c in row["candidates"].split("; "):
            if c:
                related.add(c.split("(")[0])
    rrows = []
    for iid in sorted(related, key=lambda k: (items.get(k, {}).get("rarity", 9), k)):
        i = items.get(iid)
        if i is None:
            rrows.append({"item_id": iid, "missing": True})
            continue
        rrows.append({"item_id": iid, "name_zh": i["name_zh"], "rarity": i["rarity"], "color": RARITY[i["rarity"]],
                      "tags": ",".join(i["tags"]), "material": i["material"] or None, "crystal_family": i["crystal_family"] or None,
                      "has_combat": i.get("combat") is not None, "in_random_pool": i["in_random_pool"],
                      "channels_by_rule": "; ".join(channels(i)), "named_refs": "; ".join(refs.get(iid, [])),
                      "roles": ",".join(role(iid)), "recipes_as_input": ",".join(as_input.get(iid, [])),
                      "recipes_as_output": ",".join(as_output.get(iid, [])),
                      "predicate_fits": ",".join(row["predicate"] for row in cand_rows if (iid + "(") in row["candidates"]),
                      "missing": False})
    write_csv(os.path.join(out_dir, "related_items.csv"), rrows)

    mats = [i for i in items.values() if "material" in i["tags"] or "crystal" in i["tags"]]
    write_csv(os.path.join(out_dir, "materials_all.csv"), [
        {"item_id": i["id"], "name_zh": i["name_zh"], "rarity": i["rarity"], "material": i["material"] or None,
         "crystal_family": i["crystal_family"] or None, "in_random_pool": i["in_random_pool"],
         "fits_predicates": ",".join(row["predicate"] for row in cand_rows if (i["id"] + "(") in row["candidates"]),
         "named_in_recipes": ",".join(as_input.get(i["id"], []))} for i in sorted(mats, key=lambda x: (x["material"], x["rarity"], x["id"]))])

    # —— 家族：武器节点的连通分量（只沿配方边，材料不连）——
    adj = defaultdict(set)
    edges = []
    for r in rel:
        ins = [x.split("×")[0] for x in r["inputs"].split(" + ") if x]
        w_in = [x for x in ins if x in weapons]
        if r["output"] in weapons:
            for x in w_in:
                adj[x].add(r["output"])
                adj[r["output"]].add(x)
            edges.append((tuple(ins), r["material_predicates"], r["output"], r["recipe_id"], r["kind"]))
    seen, comps = set(), []
    for wid in sorted(weapons):
        if wid in seen:
            continue
        stack, comp = [wid], []
        seen.add(wid)
        while stack:
            x = stack.pop()
            comp.append(x)
            for y in adj[x]:
                if y not in seen:
                    seen.add(y)
                    stack.append(y)
        comps.append(sorted(comp, key=lambda k: (weapons[k]["rarity"], k)))
    comps.sort(key=lambda c: (-len(c), c[0]))

    def longest(start, memo={}):
        if start in memo:
            return memo[start]
        best = 0
        for e in edges:
            if start in e[0] and e[2] in weapons and e[2] != start:
                best = max(best, 1 + longest(e[2]))
        memo[start] = best
        return best

    lines = ["# 304 附表：武器家族路线图（按配方边连通）", "",
             "口径：节点 = 带 `weapon` 标签的作者道具（不含赐福异体）；边 = 一张配方，输出是武器、输入里有武器。",
             "材料 / 磨刀石等非武器输入写在边上，不当节点；`A + B → C` 是一张配方，不是两条独立路径。",
             "链长 = 从该节点沿配方能走到的最长步数（每张配方 1 步）。独立武器（无任何配方边）单列在最后。", ""]
    solo = []
    for n, comp in enumerate(comps, 1):
        if len(comp) == 1 and not as_input.get(comp[0]) and not as_output.get(comp[0]):
            solo.append(comp[0])
            continue
        roots = [w for w in comp if not any(e[2] == w and any(x in weapons for x in e[0]) for e in edges)]
        leaves = [w for w in comp if not any(w in e[0] and e[2] in weapons for e in edges)]
        lines.append("## 家族 %d：%s（%d 把）" % (n, " / ".join(weapons[r]["name_zh"] for r in roots[:4]) + (" 等" if len(roots) > 4 else ""), len(comp)))
        lines.append("")
        lines.append("起点：%s；终点：%s；最长链：%d 步" % (", ".join("%s(%s)" % (weapons[r]["name_zh"], RARITY[weapons[r]["rarity"]]) for r in roots),
                                                ", ".join("%s(%s)" % (weapons[r]["name_zh"], RARITY[weapons[r]["rarity"]]) for r in leaves),
                                                max(longest(r) for r in roots) if roots else 0))
        lines.append("")
        lines.append("| 配方 | 类型 | 输入（完整集合） | 材料谓词 | → 成品 |")
        lines.append("|---|---|---|---|---|")
        for e in sorted(edges, key=lambda e: (weapons[e[2]]["rarity"], e[3])):
            if e[2] in comp:
                ins = " + ".join("%s %s(%s)" % (x, items[x]["name_zh"], RARITY[items[x]["rarity"]]) if x in items else x + "（缺）" for x in e[0])
                lines.append("| `%s` | %s | %s | %s | %s %s(%s) |" % (e[3], e[4], ins, e[1] or "—", e[2], weapons[e[2]]["name_zh"], RARITY[weapons[e[2]]["rarity"]]))
        lines.append("")
        # 文字树：从每个起点往下
        lines.append("```")
        def tree(x, depth, path):
            out = []
            for e in sorted(edges, key=lambda e: e[3]):
                if x in e[0] and e[2] in weapons and e[2] not in path:
                    other = [y for y in e[0] if y != x]
                    extra = (" + " + " + ".join(other)) if other else ""
                    extra += (" + 〔%s〕" % e[1]) if e[1] else ""
                    out.append("  " * depth + "└ %s%s → %s %s(%s)" % ("", extra.strip(" +") and extra, e[2], weapons[e[2]]["name_zh"], RARITY[weapons[e[2]]["rarity"]]))
                    out += tree(e[2], depth + 1, path | {e[2]})
            return out
        for r in roots:
            lines.append("%s %s(%s)" % (r, weapons[r]["name_zh"], RARITY[weapons[r]["rarity"]]))
            lines += tree(r, 1, {r})
        lines.append("```")
        lines.append("")
    lines.append("## 无任何配方关系的武器（%d 把）" % len(solo))
    lines.append("")
    lines.append("| id | 名字 | 颜色 | 标签 |")
    lines.append("|---|---|---|---|")
    for s in sorted(solo, key=lambda k: (weapons[k]["rarity"], k)):
        lines.append("| `%s` | %s | %s | %s |" % (s, weapons[s]["name_zh"], RARITY[weapons[s]["rarity"]], ",".join(weapons[s]["tags"])))
    with open(os.path.join(out_dir, "families.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    summary = {
        "items_authored_loaded": len(items), "blessed_variants_excluded": len(blessed), "weapons": len(weapons),
        "weapons_by_rarity": {RARITY[k]: sum(1 for w in weapons.values() if w["rarity"] == k) for k in range(6)},
        "recipes_total": len(rel), "recipes_by_kind": {k: sum(1 for r in rel if r["kind"] == k) for k in sorted({r["kind"] for r in rel})},
        "recipes_output_weapon": sum(1 for r in rel if r["output_is_weapon"]),
        "broken_refs": [r["recipe_id"] for r in rel if r["inputs_missing"] or r["output_missing"]],
        "families": sum(1 for c in comps if not (len(c) == 1 and c[0] in solo)), "solo_weapons": len(solo),
        "weapons_role_counts": {},
        "outputs_with_multiple_recipes": {k: v for k, v in as_output.items() if len(v) > 1 and k in weapons},
        "search_rarity_weights": search_w, "shop_rarity_weights": shop_w, "enemy_weapon_caps": pools,
        "market": {"rarity_cap_per_level": market["rarity_cap_per_level"], "loose_rarity_weights": market["loose_rarity_weights"]},
    }
    for w in wrows:
        for x in w["roles"].split(","):
            summary["weapons_role_counts"][x] = summary["weapons_role_counts"].get(x, 0) + 1
    with open(os.path.join(out_dir, "summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1)
    print(json.dumps(summary, ensure_ascii=False, indent=1))


def write_csv(path, rows):
    if not rows:
        open(path, "w").close()
        return
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for r in rows:
            w.writerow({k: ("null" if r.get(k) is None else r.get(k)) for k in keys})


if __name__ == "__main__":
    main()
