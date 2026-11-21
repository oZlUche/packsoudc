## 355 第三批：强力搭配记录（报告 355 第四节）—— 同种不限份数，「整锅只放一种」就是每条属性的上限。
##
## - [method lines]：三档锅（4×4 / 5×5 / 6×6）里，每条属性的固定值线、百分比线各挑最强的一件，先摆两格主食（酸麦 + 黑豆，饱腹 10，
##   约走 10 个新节点），剩下的格子真摆这一件（可转向）摆到摆不下，记下能摆几份、这一锅加多少；主食那两条不留主食，整锅只放它。
## - [method samples]：再抽样混搭的锅（随机挑食材往锅里塞到塞不下），每条属性记最高的那一锅。
## - [method finals]：按每位角色和科技点满（扛重 +50% 负重上限）算终值。
## 纯计算，不碰存档；以后每加一种食材重跑 `tools/canteen_combos.gd`
class_name CanteenAudit
extends RefCounted

const SIDES: Array[int] = [4, 5, 6]
## 先摆的两格主食
const BASE_STAPLES: Array[StringName] = [&"sour_wheat", &"black_bean"]
## 科技点满时负重上限的百分比（扛重三级，`tech_hauling_3`）
const TECH_CARRY_PCT := 50.0
const FLAT := "flat"
const PCT := "pct"


## 一件食材在 [param side]×[param side] 的锅里先摆 [param first]、再摆它摆满：返回锅里所有道具
static func fill(def: ItemDef, side: int, items: ItemDatabase, first: Array[StringName] = []) -> Array:
	var pot := GridInventory.new(Vector2i(side, side), 0, false)
	var uid := 1
	for id in first:
		var d := items.get_def(id)
		if d != null:
			var inst := ItemInstance.create(d)
			inst.uid = uid
			uid += 1
			pot.try_add(inst, true)
	while true:
		var inst := ItemInstance.create(def)
		inst.uid = uid
		uid += 1
		if not pot.try_add(inst, true):
			break
	return pot.items()


## 每条属性、每条线（固定 / 百分比）最强的那件：[{"stat", "line", "id", "count", "value": {side: 这一锅这条线加多少}, "satiety": {side: 饱腹}}]
static func lines(items: ItemDatabase, rules: CanteenRules = null) -> Array[Dictionary]:
	var r := rules if rules != null else Canteen.load_rules()
	var out: Array[Dictionary] = []
	for stat in Canteen.STATS:
		for line in [FLAT, PCT]:
			var best := {}
			for id in r.entries:
				var def := items.get_def(StringName(String(id)))
				var e := Canteen.entry_of(def, r)
				if e.is_empty() or StringName(e["stat"]) != stat or not e.has(line):
					continue
				var row := {"stat": stat, "line": line, "id": StringName(String(id)), "count": {}, "value": {}, "satiety": {}}
				var first: Array[StringName] = []
				if stat != Canteen.CARRY:
					first = BASE_STAPLES
				for side in SIDES:
					var pot := fill(def, side, items, first)
					var meal := Canteen.meal_of(pot, r)
					row["count"][side] = int((meal["ids"] as Dictionary).get(String(id), 0))
					row["value"][side] = float((meal[line] as Dictionary).get(String(stat), 0.0))
					row["satiety"][side] = int(meal["satiety"])
				if best.is_empty() or float(row["value"][6]) > float(best["value"][6]):
					best = row
			if not best.is_empty():
				out.append(best)
	return out


## 抽样混搭 [param n] 锅（[param side]×[param side]）：每条属性、每条线记最高那一锅 {"stat:line": {"value", "ids", "satiety"}}
static func samples(items: ItemDatabase, side: int, n: int, seed_: int, rules: CanteenRules = null) -> Dictionary:
	var r := rules if rules != null else Canteen.load_rules()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var ids: Array = r.entries.keys()
	ids.sort()
	var top := {}
	for _k in n:
		var pot := GridInventory.new(Vector2i(side, side), 0, false)
		var misses := 0
		var uid := 1
		while misses < 6:
			var def := items.get_def(StringName(String(ids[rng.randi_range(0, ids.size() - 1)])))
			var inst := ItemInstance.create(def)
			inst.uid = uid
			uid += 1
			if not pot.try_add(inst, true):
				misses += 1
		var meal := Canteen.meal_of(pot.items(), r)
		for stat in Canteen.STATS:
			for line in [FLAT, PCT]:
				var key := "%s:%s" % [stat, line]
				var v := float((meal[line] as Dictionary).get(String(stat), 0.0))
				if not top.has(key) or v > float(top[key]["value"]):
					top[key] = {"value": v, "ids": meal["ids"], "satiety": int(meal["satiety"])}
	return top


## 一锅 [param meal] 对每位角色的终值：[{"name", "base", "final", "tech"}]（tech = 科技点满时，只有负重上限不一样）
static func finals(chars: Array, meal: Dictionary, stat: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in chars:
		var ch := c as CharacterDef
		if ch == null or (stat == Canteen.CARRY and ch.weight_capacity <= 0):
			continue
		var b := Canteen.base_of(ch, stat)
		var f := b + Canteen.gain_for(ch, meal, stat)
		var tech := f
		if stat == Canteen.CARRY:
			var with_tech := meal.duplicate(true)
			var pct: Dictionary = with_tech.get("pct", {})
			pct[String(stat)] = float(pct.get(String(stat), 0.0)) + TECH_CARRY_PCT
			with_tech["pct"] = pct
			tech = Canteen.final_value(b, with_tech, stat)
		out.append({"name": Names.of(ch), "base": b, "final": f, "tech": tech})
	return out


## 整份记录（Markdown）
static func report(items: ItemDatabase, chars: Array, n_samples: int = 400, seed_: int = 355) -> String:
	var r := Canteen.load_rules()
	var md: Array[String] = []
	md.append("## 表一 · 整锅只放一种（主食以外先摆酸麦 + 黑豆）")
	md.append("")
	md.append("| 属性 | 线 | 最强一件 | 4×4 | 5×5 | 6×6 | 6×6 饱腹 |")
	md.append("|---|---|---|---:|---:|---:|---:|")
	var rows := lines(items, r)
	for row in rows:
		var stat := StringName(row["stat"])
		var cells: Array[String] = []
		for side in SIDES:
			cells.append("%s（%d 份）" % [_fmt(stat, String(row["line"]), float(row["value"][side])), int(row["count"][side])])
		md.append("| %s | %s | %s | %s | %d |" % [UiText.t("canteen.stat_" + String(stat)), "固定" if row["line"] == FLAT else "百分比",
			Names.of(items.get_def(StringName(row["id"]))), " | ".join(cells), int(row["satiety"][6])])
	md.append("")
	md.append("## 表二 · 6×6 整锅只放一种，按角色算终值（负重上限另列科技点满）")
	md.append("")
	md.append("| 属性 | 线 | 角色 | 基数 | 终值 | 科技点满 |")
	md.append("|---|---|---|---:|---:|---:|")
	for row in rows:
		var stat := StringName(row["stat"])
		var key := String(stat)
		var meal := {"flat": {}, "pct": {}}
		(meal[String(row["line"])] as Dictionary)[key] = float(row["value"][6])
		for f in finals(chars, meal, stat):
			md.append("| %s | %s | %s | %s | %s | %s |" % [UiText.t("canteen.stat_" + key), "固定" if row["line"] == FLAT else "百分比", f["name"],
				Canteen.num(float(f["base"])), Canteen.num(snappedf(float(f["final"]), 0.01)), Canteen.num(snappedf(float(f["tech"]), 0.01))])
	md.append("")
	md.append("## 表三 · 抽样混搭 %d 锅（6×6），每条线最高的一锅" % n_samples)
	md.append("")
	md.append("| 属性 | 线 | 最高 | 饱腹 | 那一锅 |")
	md.append("|---|---|---:|---:|---|")
	var top := samples(items, 6, n_samples, seed_, r)
	for stat in Canteen.STATS:
		for line in [FLAT, PCT]:
			var key := "%s:%s" % [stat, line]
			if not top.has(key):
				continue
			var t: Dictionary = top[key]
			var parts: Array[String] = []
			var ids: Array = (t["ids"] as Dictionary).keys()
			ids.sort()
			for id in ids:
				parts.append("%s ×%d" % [Names.of(items.get_def(StringName(String(id)))), int(t["ids"][id])])
			md.append("| %s | %s | %s | %d | %s |" % [UiText.t("canteen.stat_" + String(stat)), "固定" if line == FLAT else "百分比",
				_fmt(stat, line, float(t["value"])), int(t["satiety"]), "、".join(parts)])
	return "\n".join(PackedStringArray(md)) + "\n"


static func _fmt(stat: StringName, line: String, v: float) -> String:
	if line == PCT:
		return ("生命上限 %s%% / 秒" if stat == BattleStats.REGEN_HP else "+%s%%") % Canteen.num(snappedf(v, 0.01))
	return ("%s / 秒" if stat == BattleStats.REGEN_HP or stat == BattleStats.REGEN_STAMINA else "+%s") % Canteen.num(snappedf(v, 0.01))
