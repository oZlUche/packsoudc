## 平衡检测方案（2026-11-10）§7：参考配装的合法性与预算。扫表用的木桩先过这一关：道具都在、摆得回去、独一的不重复、
## 声明的核心件真的放进去了、生成器丢掉的件要报出来（不能悄悄算完成），预算同时记格子、重量、价值。
## 不拿待校准的战力估计当等成本的定义。
class_name ScenarioCheck
extends RefCounted

const UNKNOWN := "unknown_item"
const ILLEGAL := "illegal_layout"
const UNIQUE_REPEAT := "unique_repeat"
const CORE_MISSING := "core_missing"
const DROPPED := "dropped"
const OVER_BUDGET := "over_budget"
const OVERWEIGHT := "overweight"


## 预算：{items（不算包的件数）, bags, cells（物品占的格）, board_cells, weight, value, dropped（生成器没摆上的件数）}；认不得的件不计
static func budget_of(dummy: Dictionary, items: ItemDatabase) -> Dictionary:
	var out := {"items": 0, "bags": 0, "cells": 0, "board_cells": 0, "weight": 0, "value": 0, "dropped": (dummy.get("left", []) as Array).size()}
	var size: Variant = dummy.get("board_size")
	if size is Array and (size as Array).size() >= 2:
		out["board_cells"] = int(size[0]) * int(size[1])
	for e in dummy.get("layout", []):
		if not (e is Dictionary):
			continue
		var d := items.get_def(IdAliases.item(StringName(String((e as Dictionary).get("id", "")))))
		if d == null:
			continue
		if d.is_bag:
			out["bags"] = int(out["bags"]) + 1
			continue
		out["items"] = int(out["items"]) + 1
		out["cells"] = int(out["cells"]) + d.cell_count()
		out["weight"] = int(out["weight"]) + d.weight
		out["value"] = int(out["value"]) + d.value
	return out


## 一份配装的问题，每条「原因:细节」；空数组 = 合法。[param weight_capacity] 大于 0 时再查超重。
## 核心件：木桩写了 `core` 就按它，没写按 `picked`（生成器挑中的）；每件都要在棋盘上（按件数算）
static func problems(dummy: Dictionary, items: ItemDatabase, weight_capacity: int = 0) -> Array[String]:
	var out: Array[String] = []
	var placed := {}
	for e in dummy.get("layout", []):
		if not (e is Dictionary):
			continue
		var raw := StringName(String((e as Dictionary).get("id", "")))
		var id := IdAliases.item(raw)
		var d := items.get_def(id)
		if d == null:
			out.append("%s:%s" % [UNKNOWN, raw])
			continue
		placed[id] = int(placed.get(id, 0)) + 1
		if d.is_unique() and int(placed[id]) == 2:
			out.append("%s:%s" % [UNIQUE_REPEAT, id])
	if out.is_empty():
		var why := DataAudit.layout_problem(dummy, items)
		if why != "":
			out.append(why)
	var want := {}
	for raw in dummy.get("core", dummy.get("picked", [])):
		var id := IdAliases.item(StringName(String(raw)))
		want[id] = int(want.get(id, 0)) + 1
	for id in want:
		if int(placed.get(id, 0)) < int(want[id]):
			out.append("%s:%s" % [CORE_MISSING, id])
	for raw in dummy.get("left", []):
		out.append("%s:%s" % [DROPPED, raw])
	var b := budget_of(dummy, items)
	var cap: Dictionary = dummy.get("budget", {}) if dummy.get("budget") is Dictionary else {}
	for key in cap:
		if b.has(key) and int(b[key]) > int(cap[key]):
			out.append("%s:%s" % [OVER_BUDGET, key])
	if weight_capacity > 0 and int(b["weight"]) > weight_capacity:
		out.append("%s:%d/%d" % [OVERWEIGHT, int(b["weight"]), weight_capacity])
	return out


## 一整份木桩表：{key → {problems, budget}}，外加 {legal, illegal}
static func check_all(dummies: Dictionary, items: ItemDatabase, weight_capacity: int = 0) -> Dictionary:
	var rows := {}
	var bad := 0
	var keys: Array = dummies.keys()
	keys.sort()
	for k in keys:
		var d: Dictionary = dummies[k]
		var p := problems(d, items, weight_capacity)
		if not p.is_empty():
			bad += 1
		rows[k] = {"problems": p, "budget": budget_of(d, items)}
	return {"rows": rows, "legal": keys.size() - bad, "illegal": bad}
