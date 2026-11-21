## 355：灰灯食堂（报告 355，342 的 B4）—— 灰灯到受托并办完《开伙》后，后勤「食堂」页里往锅里摆食材，出征吃掉这一锅。
##
## - 食材 = 带「食材」标签（[constant TAG]）的生料；成品食物（口粮这一类）不是食材，不能下锅。
## - 食材仓库（[member store]）和锅（[member pot]）都是格子盘，只收食材；大小按灰灯的声望档（[method CanteenRules.pot_size] / [method CanteenRules.store_size]），只长不缩。
## - 一锅的效果（[method meal_of]）：四类各管一种属性，同一属性固定值相加、百分比相加；主食另外给饱腹。
##   负重上限、耐力上限、耐力回复和科技同一条算式（[method RunContext.scaled]：基数 ×（1 + Σ%）+ Σ固定）；
##   战斗中每秒回血是独立的一项，只在水果之间相加，不吃别的治疗、回复加成（[member CombatantSpec.meal_regen_hp]）。
## - 一局里的饱腹与效果在 [MealModule]。纯逻辑，存盘由 [GameFlow] 做
class_name Canteen
extends RefCounted

const ID := &"canteen"
## 食材标签
const TAG := &"ingredient"
const STORE_ID := 103
const POT_ID := 104
## 四种属性（负重上限不是战斗属性，单独一个键）
const CARRY := &"carry"
const STAT_OF := {
	CanteenRules.STAPLE: CARRY, CanteenRules.MEAT: BattleStats.MAX_STAMINA,
	CanteenRules.VEG: BattleStats.REGEN_STAMINA, CanteenRules.FRUIT: BattleStats.REGEN_HP,
}
const STATS: Array[StringName] = [CARRY, BattleStats.MAX_STAMINA, BattleStats.REGEN_STAMINA, BattleStats.REGEN_HP]
## 防溢出：每条属性汇总后的上限（固定值、百分数）。整锅放同一件也到不了，只防坏数据
const CAP_FLAT := 999.0
const CAP_PCT := 1000.0
## 355：食材在普通搜索里的权重倍数（报告 355 第八节「权重低」）
const SEARCH_WEIGHT := 0.25

static var _rules: CanteenRules = null
## 提示窗按谁算「对当前角色实际加多少」（食堂页 = 上回出征那位，开局屏 = 选着的那位；空 = 不写）
static var viewer: CharacterDef = null

## 食材仓库
var store: GridInventory = null
## 锅：摆进去的算已经拿出仓库，拖回去回到仓库；出征成功时吃掉
var pot: GridInventory = null
## 旧档里已有的薄荷叶束、蜂蜜罐这类食材，开放那一刻从主仓库搬进食材仓库一次（[method GameFlow.sync_canteen]）
var moved_legacy := false
## 收藏上限（报告 355 §7：先定 8 份）、名字最长几个字
const MAX_MENUS := 8
const NAME_MAX := 10
## 收藏的菜单 [{"name": 名字, "cells": [{"id": 道具 id, "x", "y", "rot"}]}]：收的是种类、份数和摆法，不是那几件道具
var menus: Array[Dictionary] = []
## 锅里这一锅是照哪份收藏摆的（-1 = 没照收藏）。之后再改锅也还算这一份，缺的位置见 [method gaps]
var active := -1


func _init(store_size: Vector2i = Vector2i(6, 6), pot_size: Vector2i = Vector2i(4, 4)) -> void:
	store = _grid(store_size, STORE_ID)
	pot = _grid(pot_size, POT_ID)


static func load_rules() -> CanteenRules:
	if _rules == null:
		_rules = ContentPaths.load_asset("base_rules", String(CanteenRules.ID)) as CanteenRules
		if _rules == null:
			_rules = CanteenRules.new()
	return _rules


static func _grid(size: Vector2i, id: int) -> GridInventory:
	var g := GridInventory.new(size, id, false)
	g.only_tags.assign([TAG])
	return g


static func is_ingredient(def: ItemDef) -> bool:
	return def != null and def.tags.has(TAG)


## 灰灯现在第几档
static func tier(meta: MetaState, rules: CanteenRules = null) -> int:
	var r := rules if rules != null else load_rules()
	return Commissions.tier_of(meta.commissions if meta != null else null, Commissions.faction(r.faction))


## 按 [param tier] 档把锅和食材仓库调到该有的大小（只长不缩）。换了格子盘返回放不回去的那几件（正常是空），由调用方安置
func fit(p_tier: int, rules: CanteenRules = null) -> Array[ItemInstance]:
	var r := rules if rules != null else load_rules()
	var left: Array[ItemInstance] = []
	var ws := r.store_size(p_tier)
	if ws.x > store.size.x or ws.y > store.size.y:
		store = _regrid(store, Vector2i(maxi(ws.x, store.size.x), maxi(ws.y, store.size.y)), left)
	var wp := r.pot_size(p_tier)
	if wp.x > pot.size.x or wp.y > pot.size.y:
		pot = _regrid(pot, Vector2i(maxi(wp.x, pot.size.x), maxi(wp.y, pot.size.y)), left)
	return left


static func _regrid(old: GridInventory, size: Vector2i, left: Array[ItemInstance]) -> GridInventory:
	var g := _grid(size, old.id)
	var all: Array = old.items()
	all.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.placed_seq < b.placed_seq)
	g.begin_batch()
	for inst in all:
		var it := inst as ItemInstance
		it.container_id = g.id     # 原样放回不算「新置入」，序号留着
		if not g.place(it, it.origin, it.rotation) and not g.try_add(it, true):
			left.append(it)
	g.end_batch()
	return g


## 收一件进食材仓库（不是食材、放不下返回 false）
func stash(inst: ItemInstance) -> bool:
	return inst != null and is_ingredient(inst.def) and store.try_add(inst, true)


#region 一锅
## 一锅食材 → {"flat": {属性: Σ固定}, "pct": {属性: Σ百分数}, "satiety": 饱腹度, "count": 几份, "ids": {道具 id: 几份}}。
## 不是食材、表里没有的不算。四种属性见 [constant STATS]；回血的百分比是「每秒回生命上限的百分之几」
static func meal_of(items: Array, rules: CanteenRules = null) -> Dictionary:
	var r := rules if rules != null else load_rules()
	var flat := {}
	var pct := {}
	var satiety := 0
	var count := 0
	var ids := {}
	for inst in items:
		var it := inst as ItemInstance
		if it == null or not is_ingredient(it.def):
			continue
		var e := r.entry(it.def.id)
		var stat: StringName = STAT_OF.get(StringName(String(e.get("category", ""))), &"")
		if stat == &"":
			continue
		count += 1
		ids[String(it.def.id)] = int(ids.get(String(it.def.id), 0)) + 1
		satiety += maxi(0, int(e.get("satiety", 0)))
		var key := String(stat)     # 键用 String：存档读回来一样
		if e.has("flat"):
			flat[key] = float(flat.get(key, 0.0)) + float(e["flat"])
		elif e.has("pct"):
			pct[key] = float(pct.get(key, 0.0)) + float(e["pct"])
	for k in flat:
		flat[k] = clampf(float(flat[k]), 0.0, CAP_FLAT)
	for k in pct:
		pct[k] = clampf(float(pct[k]), 0.0, CAP_PCT)
	return {"flat": flat, "pct": pct, "satiety": satiety, "count": count, "ids": ids}


## 锅里这一锅
func current_meal(rules: CanteenRules = null) -> Dictionary:
	return meal_of(pot.items(), rules)


## 一件食材自己的那一条：{"stat", "flat" 或 "pct", "satiety"}（不是食材 = 空）
static func entry_of(def: ItemDef, rules: CanteenRules = null) -> Dictionary:
	if not is_ingredient(def):
		return {}
	var r := rules if rules != null else load_rules()
	var e := r.entry(def.id)
	var stat: StringName = STAT_OF.get(StringName(String(e.get("category", ""))), &"")
	if stat == &"":
		return {}
	var out := {"stat": stat, "satiety": int(e.get("satiety", 0))}
	if e.has("flat"):
		out["flat"] = float(e["flat"])
	elif e.has("pct"):
		out["pct"] = float(e["pct"])
	return out


## 某属性的终值：基数 ×（1 + Σ%）+ Σ固定（和科技同一条算式，[method RunContext.scaled] 的浮点版）
static func final_value(base: float, meal: Dictionary, stat: StringName) -> float:
	var f := float((meal.get("flat", {}) as Dictionary).get(String(stat), 0.0))
	var p := float((meal.get("pct", {}) as Dictionary).get(String(stat), 0.0))
	return base * (100.0 + p) / 100.0 + f


## 一条属性那一行：「耐力上限 +3 · +5%」；回血：「每秒回血 1.7 · 生命上限的 2%」。没有 = 空串
static func line_of(meal: Dictionary, stat: StringName) -> String:
	var f := float((meal.get("flat", {}) as Dictionary).get(String(stat), 0.0))
	var p := float((meal.get("pct", {}) as Dictionary).get(String(stat), 0.0))
	if f == 0.0 and p == 0.0:
		return ""
	var parts: Array[String] = []
	if f != 0.0:
		parts.append("+" + num(f))
	if p != 0.0:
		parts.append((UiText.t("canteen.hp_pct") if stat == BattleStats.REGEN_HP else "+%s%%") % num(p))
	return UiText.t("canteen.line") % [UiText.t("canteen.stat_" + String(stat)), UiText.t("tip.list_sep").join(parts)]


## 角色身上这条属性吃饭前的基数：负重上限 = 角色的负重上限（没有负重 = 0）；战斗回血 = 0；别的照面板
static func base_of(ch: CharacterDef, stat: StringName) -> float:
	if ch == null:
		return 0.0
	if stat == CARRY:
		return float(maxi(0, ch.weight_capacity))
	if stat == BattleStats.REGEN_HP:
		return 0.0
	return ch.baseline().value_of(stat)


## 这一锅给 [param ch] 加了多少（终值 − 基数）。战斗回血 = 固定 + 生命上限 × 百分比
static func gain_for(ch: CharacterDef, meal: Dictionary, stat: StringName) -> float:
	if ch == null:
		return 0.0
	if stat == BattleStats.REGEN_HP:
		var f := float((meal.get("flat", {}) as Dictionary).get(String(stat), 0.0))
		var p := float((meal.get("pct", {}) as Dictionary).get(String(stat), 0.0))
		return f + ch.baseline().value_of(BattleStats.MAX_HP) * p / 100.0
	var b := base_of(ch, stat)
	return final_value(b, meal, stat) - b


## 一件食材单独下锅的那一锅（提示窗用）
static func single_meal(def: ItemDef) -> Dictionary:
	var e := entry_of(def)
	if e.is_empty():
		return {}
	var k := String(e["stat"])
	return {"flat": {k: e["flat"]} if e.has("flat") else {}, "pct": {k: e["pct"]} if e.has("pct") else {}, "satiety": int(e.get("satiety", 0))}


## 按 [param ch] 算好的每一行「耐力上限 30 → 34.5」（只列锅里加了的；没有负重的角色不列负重）
static func final_lines(ch: CharacterDef, meal: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if ch == null:
		return out
	for stat in STATS:
		if line_of(meal, stat) == "" or (stat == CARRY and ch.weight_capacity <= 0):
			continue
		var b := base_of(ch, stat)
		out.append(UiText.t("canteen.final") % [UiText.t("canteen.stat_" + String(stat)), num(b), num(b + gain_for(ch, meal, stat))])
	return out


## 数字：整数不带小数点，带小数的留到两位（0.25）
static func num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, 2)
#endregion


#region 收藏菜单（报告 355 §7）
## 一块盘的摆法：[{"id", "x", "y", "rot"}]，按摆进去的先后排
static func layout_of(grid: GridInventory) -> Array[Dictionary]:
	var all: Array = grid.items()
	all.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.placed_seq < b.placed_seq)
	var out: Array[Dictionary] = []
	for inst in all:
		var it := inst as ItemInstance
		out.append({"id": String(it.def.id), "x": it.origin.x, "y": it.origin.y, "rot": it.rotation})
	return out


## 把锅里这一锅收藏起来（名字空 = 「菜单 N」取最小的空号）。满了、锅是空的返回 -1；成了返回第几份，锅就算照它摆的
func save_menu(p_name: String = "") -> int:
	if menus.size() >= MAX_MENUS or pot.item_count() == 0:
		return -1
	var n := _clean(p_name)
	if n == "":
		n = default_name()
	menus.append({"name": n, "cells": layout_of(pot)})
	active = menus.size() - 1
	return active


## 还没用过的最小号「菜单 N」
func default_name() -> String:
	var used := {}
	for m in menus:
		used[String(m.get("name", ""))] = true
	var k := 1
	while used.has(UiText.t("canteen.menu_default") % k):
		k += 1
	return UiText.t("canteen.menu_default") % k


static func _clean(p_name: String) -> String:
	return p_name.strip_edges().left(NAME_MAX)


## 改名（空名不认）
func rename_menu(i: int, p_name: String) -> bool:
	var n := _clean(p_name)
	if i < 0 or i >= menus.size() or n == "":
		return false
	menus[i]["name"] = n
	return true


## 删一份；锅照的就是它 → 锅不再算照收藏
func delete_menu(i: int) -> bool:
	if i < 0 or i >= menus.size():
		return false
	menus.remove_at(i)
	if active == i:
		active = -1
	elif active > i:
		active -= 1
	return true


## 锅现在的名字：照收藏摆的 = 那份的名字；否则空串
func menu_name() -> String:
	return String(menus[active].get("name", "")) if active >= 0 and active < menus.size() else ""


## 一键重做：锅里已经在原位的那几件留着，别的回食材仓库；再从食材仓库按原样取料摆好。
## 返回缺料（或位置被占）的那几格 [{"id", "x", "y", "rot"}]。锅里的东西回不去仓库的（仓库满了）留在锅里，不丢
func load_menu(i: int) -> Array[Dictionary]:
	var gaps_out: Array[Dictionary] = []
	if i < 0 or i >= menus.size():
		return gaps_out
	var cells: Array = menus[i].get("cells", [])
	var keep := {}
	var todo: Array = []
	for c in cells:
		var uid := _match(c)
		if uid != GridInventory.EMPTY_UID and not keep.has(uid):
			keep[uid] = true
		else:
			todo.append(c)
	pot.begin_batch()
	store.begin_batch()
	for inst in pot.items():
		var it := inst as ItemInstance
		if keep.has(it.uid):
			continue
		pot.remove(it.uid)
		if not store.try_add(it, true):
			pot.place(it, it.origin, it.rotation)
	for c in todo:
		var at := Vector2i(int(c.get("x", 0)), int(c.get("y", 0)))
		var rot := int(c.get("rot", 0))
		var it := _from_store(StringName(String(c.get("id", ""))), at, rot)
		if it == null:
			gaps_out.append(c)
	store.end_batch()
	pot.end_batch()
	active = i
	return gaps_out


## 锅里 (x, y) 正好摆着这一样、朝向也对 → 那件的 uid，否则 [constant GridInventory.EMPTY_UID]
func _match(c: Dictionary) -> int:
	var at := Vector2i(int(c.get("x", 0)), int(c.get("y", 0)))
	var uid := pot.cell_uid(at)
	var it := pot.get_item(uid) if uid != GridInventory.EMPTY_UID else null
	if it != null and String(it.def.id) == String(c.get("id", "")) and it.origin == at and it.rotation == int(c.get("rot", 0)):
		return uid
	return GridInventory.EMPTY_UID


## 从食材仓库取一件 [param id] 摆到锅的 [param at]（玩家锁着的不取）。摆不下放回仓库原处，返回 null
func _from_store(id: StringName, at: Vector2i, rot: int) -> ItemInstance:
	for inst in store.items():
		var it := inst as ItemInstance
		if it.def.id != id or it.is_locked_by_player():
			continue
		if not pot.can_place_def(it.def, at, rot):
			return null
		var home := it.origin
		var home_rot := it.rotation
		store.remove(it.uid)
		if pot.place(it, at, rot):
			return it
		store.place(it, home, home_rot)
		return null
	return null


## 照着的那份收藏里，锅里现在对不上的那几格（缺料、被换掉的）。没照收藏 = 空
func gaps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if active < 0 or active >= menus.size():
		return out
	var used := {}
	for c in menus[active].get("cells", []):
		var uid := _match(c)
		if uid == GridInventory.EMPTY_UID or used.has(uid):
			out.append(c)
		else:
			used[uid] = true
	return out
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {"store": store.to_dict(), "pot": pot.to_dict(), "moved_legacy": moved_legacy, "menus": menus.duplicate(true), "active": active}


## 读回来；格子盘按存档里的大小建（档位由 [method fit] 之后再调）。认不得的道具由 [method GridInventory.from_dict] 告警丢弃
static func from_dict(d: Variant, items: ItemDatabase) -> Canteen:
	var c := Canteen.new()
	if not (d is Dictionary) or items == null:
		return c
	var src := d as Dictionary
	for pair in [["store", STORE_ID], ["pot", POT_ID]]:
		var raw: Variant = src.get(pair[0], null)
		if raw is Dictionary:
			var g := GridInventory.from_dict(raw as Dictionary, items)
			g.id = int(pair[1])
			g.only_tags.assign([TAG])
			c.set(pair[0], g)
	c.moved_legacy = bool(src.get("moved_legacy", false))
	var raw_menus: Variant = src.get("menus", [])
	if raw_menus is Array:
		for m in raw_menus as Array:
			if m is Dictionary and c.menus.size() < MAX_MENUS:
				var cells: Array[Dictionary] = []
				for cell in (m as Dictionary).get("cells", []):
					if cell is Dictionary:
						var cd := cell as Dictionary
						cells.append({"id": String(cd.get("id", "")), "x": int(cd.get("x", 0)), "y": int(cd.get("y", 0)), "rot": int(cd.get("rot", 0))})
				c.menus.append({"name": String((m as Dictionary).get("name", "")), "cells": cells})
	c.active = int(src.get("active", -1))
	if c.active >= c.menus.size():
		c.active = -1
	return c
#endregion
