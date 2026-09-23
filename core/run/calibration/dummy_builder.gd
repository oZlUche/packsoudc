## 木桩（069 第七节第 7 条，报告 073）：把许多局的快照按步数分段，每段生成一个「平均玩家」。
##
## 平均的是**读数**（生命、预估 DPS），木桩本身是这一段里离平均最近的那份真实配置（medoid）——
## 一堆道具清单没法平均，但一块真的棋盘能上场打。每段一份：步数范围、样本数、平均读数、木桩的棋盘与基线。
## 段长（几步一段）是参数；作者说的 3～5 个时间段，就是段长 = 一局总步数 ÷ 3～5。
## 没有真实快照时可以从开局装备造（[method from_loadouts]）：那是「第 0 段」的木桩，只够把工具跑通。
class_name DummyBuilder
extends RefCounted

const DEFAULT_PATH := "res://data/authoring/calibration/dummies.json"


## 一份快照的读数：生命、预估 DPS
static func metrics(snap: Dictionary, items: ItemDatabase) -> Dictionary:
	var spec := CalibrationRecorder.compile(snap, items)
	var dps := 0.0
	for it in spec.items:
		dps += (it as CompiledItem).estimated_dps()
	return {"hp": StatMath.to_float(spec.max_hp), "dps": dps, "items": spec.items.size()}


## 按步数分段：段号 = steps ÷ bucket。返回 {段号(String) → 木桩}
static func build(snapshots: Array[Dictionary], items: ItemDatabase, bucket: int = 5) -> Dictionary:
	var by_bucket := {}
	for snap in snapshots:
		var k := str(int(snap.get("steps", 0)) / maxi(1, bucket))
		if not by_bucket.has(k):
			by_bucket[k] = []
		(by_bucket[k] as Array).append(snap)
	var out := {}
	var keys: Array = by_bucket.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for k in keys:
		var group: Array = by_bucket[k]
		var rows: Array = []
		var sum_hp := 0.0
		var sum_dps := 0.0
		for snap in group:
			var m := metrics(snap, items)
			rows.append({"snap": snap, "m": m})
			sum_hp += float(m["hp"])
			sum_dps += float(m["dps"])
		var n := group.size()
		var avg_hp := sum_hp / n
		var avg_dps := sum_dps / n
		# 离平均最近的那份（各按平均归一后的欧氏距离）
		var best: Dictionary = rows[0]
		var best_d := INF
		for row in rows:
			var m: Dictionary = row["m"]
			var dh := (float(m["hp"]) - avg_hp) / maxf(1.0, avg_hp)
			var dd := (float(m["dps"]) - avg_dps) / maxf(0.01, avg_dps)
			var d := dh * dh + dd * dd
			if d < best_d:
				best_d = d
				best = row
		var pick: Dictionary = best["snap"]
		out[k] = {
			"steps": [int(k) * bucket, (int(k) + 1) * bucket - 1],
			"samples": n,
			"avg_hp": avg_hp,
			"avg_dps": avg_dps,
			"hp": float((best["m"] as Dictionary)["hp"]),
			"dps": float((best["m"] as Dictionary)["dps"]),
			"board_size": pick.get("board_size", [8, 6]),
			"requires_bag": pick.get("requires_bag", true),
			"layout": pick.get("layout", []),
			"baseline": pick.get("baseline", {}),
		}
	return out


## 没有真实快照：每套开局装备当一份第 0 步的快照
static func from_loadouts(loadouts: Array[LoadoutDef], items: ItemDatabase, baseline: CombatantBaseline, board_size: Vector2i = RunState.BOARD_SIZE) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l in loadouts:
		var board := GridInventory.new(board_size, RunState.BOARD_ID, true)
		var bags: Array[ItemDef] = []
		var rest: Array[ItemDef] = []
		for id in l.items:
			var d := items.get_def(id)
			if d == null:
				continue
			if d.is_bag:
				bags.append(d)
			else:
				rest.append(d)
		board.begin_batch()
		for d in bags:
			board.try_add(ItemInstance.create(d, 0), true)
		for d in rest:
			board.try_add(ItemInstance.create(d, 0), true)
		board.end_batch()
		var stats := {}
		if baseline != null:
			for key in baseline.base_stats:
				stats[String(key)] = float(baseline.base_stats[key])
		out.append({"seed": 0, "chapter": "", "character": "", "difficulty": "", "steps": 0, "searches": 0,
			"board_size": [board_size.x, board_size.y], "requires_bag": true, "layout": RunState.layout_of(board),
			"baseline": stats, "buffs": [], "loadout": String(l.id)})
	return out


## 木桩当战斗单位
static func compile(dummy: Dictionary, items: ItemDatabase) -> CombatantSpec:
	return CalibrationRecorder.compile(dummy, items)


static func save(dummies: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(dummies, "  ", false) + "\n")
	f.close()
	return OK


static func load_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
