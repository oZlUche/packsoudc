## 355：灰灯食堂（报告 355，342 的 B4）—— 灰灯 25 声望并办完《开伙》后，后勤「食堂」页里往锅里摆食材，出征吃掉这一锅。
##
## - 食材 = 带「食材」标签（[constant TAG]）的生料；成品食物（口粮这一类）不是食材，不能下锅。
## - 食材仓库（[member store]）和锅（[member pot]）都是格子盘，只收食材；大小按灰灯的声望节点（[method sizes]），只长不缩。
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
## 作者 2026-11-27（确认清单 73「让赐福的更值钱，然后效果统一 +50%」）：赐福的食材下锅照本体那一条算，加成 ×1.5，饱腹不变
## （器官的特性在 [method Blessings.derive] 派生时就乘好了）
const BLESSED_MULT := 1.5

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
## 383：这一锅在食堂按【开饭】确认了 —— 出征第一屏的食物横条只能看、不能换，锅也不能再动；出发吃掉以后清掉
var eaten := false
## 383（作者 2026-11-23）：上一局实际吃下去的那一锅 {"kind": "menu"（照配方）/ "free"（自由组合）, "name": 配方名, "cells": 摆法}。
## 上一局没吃 = 空，下次出征食物横条也是空的
var last: Dictionary = {}
const LAST_MENU := "menu"
const LAST_FREE := "free"

## 出征第一屏食物横条的七种情况（[method plan]，报告 383 第三节第 2 条的表）
const PLAN_EATEN := &"eaten"
const PLAN_UNCONFIRMED := &"unconfirmed"
const PLAN_MENU := &"menu"
const PLAN_MENU_SHORT := &"menu_short"
const PLAN_FREE := &"free"
const PLAN_FREE_SHORT := &"free_short"
const PLAN_EMPTY := &"empty"


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


## 报告 389：锅和食材仓库现在该多大 {"pot", "store"}：起始大小，和灰灯到了的 `canteen_pot` / `canteen_store` 节点里最大的
static func sizes(meta: MetaState, rules: CanteenRules = null) -> Dictionary:
	var r := rules if rules != null else load_rules()
	var f := Commissions.faction(r.faction)
	var book := meta.commissions if meta != null else null
	return {"pot": _biggest(r.pot_size(), Commissions.reached_with(book, f, &"canteen_pot")),
		"store": _biggest(r.store_size(), Commissions.reached_with(book, f, &"canteen_store"))}


static func _biggest(base: Vector2i, nodes: Array[Dictionary]) -> Vector2i:
	var out := base
	for n in nodes:
		var v: Variant = n.get("value", [])
		if v is Array and (v as Array).size() >= 2:
			out = Vector2i(maxi(out.x, int(v[0])), maxi(out.y, int(v[1])))
	return out


## 把锅和食材仓库调到 [param want]（[method sizes]）那么大（只长不缩）。换了格子盘返回放不回去的那几件（正常是空），由调用方安置
func fit(want: Dictionary) -> Array[ItemInstance]:
	var left: Array[ItemInstance] = []
	var ws: Vector2i = want.get("store", store.size)
	if ws.x > store.size.x or ws.y > store.size.y:
		store = _regrid(store, Vector2i(maxi(ws.x, store.size.x), maxi(ws.y, store.size.y)), left)
	var wp: Vector2i = want.get("pot", pot.size)
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
	var organs := {}
	for inst in items:
		var it := inst as ItemInstance
		if it == null or not is_ingredient(it.def):
			continue
		var e := table_entry(it.def, r)
		if OrganTraits.is_organ(it.def):     # 395：器官下锅给特性，放几件叠几次
			count += 1
			ids[String(it.def.id)] = int(ids.get(String(it.def.id), 0)) + 1
			for k in it.def.eat_trait:
				organs[String(k)] = float(organs.get(String(k), 0.0)) + float(it.def.eat_trait[k])
			satiety += maxi(0, int(e.get("satiety", 0)))
			continue
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
	var out := {"flat": flat, "pct": pct, "satiety": satiety, "count": count, "ids": ids}
	if not organs.is_empty():
		for k in organs:     # 防溢出（同上，只防坏数据）：特性本身不设上限；键用 String，存档读回来一样
			organs[k] = clampf(float(organs[k]), -CAP_PCT, CAP_PCT)
		out["traits"] = organs
	return out


## 锅里这一锅
func current_meal(rules: CanteenRules = null) -> Dictionary:
	return meal_of(pot.items(), rules)


## 一件食材自己的那一条：{"stat", "flat" 或 "pct", "satiety"}（不是食材 = 空）
static func entry_of(def: ItemDef, rules: CanteenRules = null) -> Dictionary:
	if not is_ingredient(def):
		return {}
	var r := rules if rules != null else load_rules()
	var e := table_entry(def, r)
	var stat: StringName = STAT_OF.get(StringName(String(e.get("category", ""))), &"")
	if stat == &"":
		return {}
	var out := {"stat": stat, "satiety": int(e.get("satiety", 0))}
	if e.has("flat"):
		out["flat"] = float(e["flat"])
	elif e.has("pct"):
		out["pct"] = float(e["pct"])
	return out


## 表里这件的那一条；赐福版（表里没登记）照本体那一条，固定值 / 百分比 ×[constant BLESSED_MULT]，饱腹不变
static func table_entry(def: ItemDef, r: CanteenRules) -> Dictionary:
	if def == null or r == null:
		return {}
	if not def.is_blessed():
		return r.entry(def.id)
	var e := r.entry(def.blessed_of).duplicate()
	for k in ["flat", "pct"]:
		if e.has(k):
			e[k] = float(e[k]) * BLESSED_MULT
	return e


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
	var traits: Variant = meal.get("traits", {})
	if traits is Dictionary and not (traits as Dictionary).is_empty():     # 395：器官的特性（好处在前），整局有效
		out.append(UiText.t("canteen.traits") % OrganTraits.line(traits))
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


## 383：【开饭】—— 锅里这一锅算吃下了（锅空不认）
func eat() -> bool:
	if pot.item_count() == 0 or eaten:
		return false
	eaten = true
	return true


## 锅倒回食材仓库（回不去的留着）
func empty_pot() -> void:
	pot.begin_batch()
	store.begin_batch()
	for inst in pot.items():
		var it := inst as ItemInstance
		pot.remove(it.uid)
		if not store.try_add(it, true):
			pot.place(it, it.origin, it.rotation)
	store.end_batch()
	pot.end_batch()
	active = -1


## 锅现在的名字：照收藏摆的 = 那份的名字；否则空串
func menu_name() -> String:
	return String(menus[active].get("name", "")) if active >= 0 and active < menus.size() else ""


## 一键重做：锅里已经在原位的那几件留着，别的回食材仓库；再从食材仓库按原样取料摆好。
## 返回缺料（或位置被占）的那几格 [{"id", "x", "y", "rot"}]。锅里的东西回不去仓库的（仓库满了）留在锅里，不丢
func load_menu(i: int) -> Array[Dictionary]:
	if i < 0 or i >= menus.size():
		return [] as Array[Dictionary]
	var gaps_out := load_cells(menus[i].get("cells", []))
	active = i
	return gaps_out


## 383：照一份摆法重做这一锅（配方或上次的组合；做法同 [method load_menu]，锅不再算照哪份配方）。返回缺料的那几格
func load_cells(cells: Array) -> Array[Dictionary]:
	var gaps_out: Array[Dictionary] = []
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
	active = -1
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


#region 383：出征第一屏的食物横条（作者 2026-11-23）
## 名字找配方（找不到 = -1）
func menu_index(p_name: String) -> int:
	for k in menus.size():
		if String(menus[k].get("name", "")) == p_name:
			return k
	return -1


## 食材仓库加锅里能凑出 [param cells] 里的哪几格（不动东西）：{"ok": [凑得出的格], "gaps": [缺料的格], "items": [对应的那几件，算效果用]}。
## 玩家锁着的不算
func coverage(cells: Array) -> Dictionary:
	var pool := {}
	for inst in store.items() + pot.items():     # 锅里摆着的出发时也能用（[method load_cells] 先把它们倒回仓库再取）
		var it := inst as ItemInstance
		if it.is_locked_by_player():
			continue
		var k := String(it.def.id)
		if not pool.has(k):
			pool[k] = []
		(pool[k] as Array).append(it)
	var ok: Array[Dictionary] = []
	var miss: Array[Dictionary] = []
	var got: Array = []
	for c in cells:
		var k := String((c as Dictionary).get("id", ""))
		var left: Array = pool.get(k, [])
		if left.is_empty():
			miss.append(c)
		else:
			got.append(left.pop_back())
			ok.append(c)
	return {"ok": ok, "gaps": miss, "items": got}


## 进出征第一屏时食物横条是哪一种：{"state": PLAN_*, "name": 配方名, "cells": 出发时要摆的格（空 = 不摆）, "meal": 这一锅的效果, "gaps": 缺几格}。
## 顺序照报告的表：开过饭 → 锅里摆着没确认 → 上次配方（够 / 不够）→ 上次组合（够 / 不够，缺的去掉）→ 空
func plan(rules: CanteenRules = null) -> Dictionary:
	if pot.item_count() > 0:
		var st := PLAN_EATEN if eaten else PLAN_UNCONFIRMED
		return {"state": st, "name": menu_name(), "cells": [], "meal": current_meal(rules), "gaps": gaps().size()}
	var cells: Array = last.get("cells", []) if last is Dictionary else []
	if cells.is_empty():
		return {"state": PLAN_EMPTY, "name": "", "cells": [], "meal": {}, "gaps": 0}
	var cov := coverage(cells)
	var miss := (cov["gaps"] as Array).size()
	var nm := String(last.get("name", ""))
	if String(last.get("kind", "")) == LAST_MENU:
		if miss > 0:
			return {"state": PLAN_MENU_SHORT, "name": nm, "cells": [], "meal": {}, "gaps": miss}
		return {"state": PLAN_MENU, "name": nm, "cells": cells, "meal": meal_of(cov["items"], rules), "gaps": 0}
	if (cov["ok"] as Array).is_empty():
		return {"state": PLAN_EMPTY, "name": "", "cells": [], "meal": {}, "gaps": miss}
	return {"state": PLAN_FREE_SHORT if miss > 0 else PLAN_FREE, "name": "", "cells": cov["ok"], "meal": meal_of(cov["items"], rules), "gaps": miss}


## 应用第 [param i] 份配方（出征第一屏用，不动锅）：{"cells", "meal", "gaps"}，缺的那几格去掉
func plan_menu(i: int, rules: CanteenRules = null) -> Dictionary:
	if i < 0 or i >= menus.size():
		return {}
	var cov := coverage(menus[i].get("cells", []))
	var st := PLAN_MENU_SHORT if (cov["ok"] as Array).is_empty() else PLAN_MENU     # 一样都凑不出 = 仍是【食材不足】（测试 v8.17）
	return {"state": st, "name": String(menus[i].get("name", "")), "cells": cov["ok"], "meal": meal_of(cov["items"], rules),
		"gaps": (cov["gaps"] as Array).size()}


## 出发吃下锅里这一锅时记下来（锅空 = 上一局没吃，记成空）。照配方摆的记配方名和配方的摆法，否则记锅的摆法
func record_eaten() -> void:
	if pot.item_count() == 0:
		last = {}
	elif active >= 0 and active < menus.size():
		last = {"kind": LAST_MENU, "name": String(menus[active].get("name", "")), "cells": (menus[active].get("cells", []) as Array).duplicate(true)}
	else:
		last = {"kind": LAST_FREE, "name": "", "cells": layout_of(pot)}
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {"store": store.to_dict(), "pot": pot.to_dict(), "moved_legacy": moved_legacy, "menus": menus.duplicate(true), "active": active,
		"eaten": eaten, "last": last.duplicate(true)}     # 383：不升版 —— 旧档没有就是没开饭、上次没吃（v8.07 的 fixed 不再读）


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
	var raw_last: Variant = src.get("last", {})     # 383
	if raw_last is Dictionary and (raw_last as Dictionary).get("cells", []) is Array:
		var l := raw_last as Dictionary
		var lc: Array[Dictionary] = []
		for cell in l.get("cells", []):
			if cell is Dictionary:
				var cd := cell as Dictionary
				lc.append({"id": String(cd.get("id", "")), "x": int(cd.get("x", 0)), "y": int(cd.get("y", 0)), "rot": int(cd.get("rot", 0))})
		if not lc.is_empty():
			c.last = {"kind": LAST_MENU if String(l.get("kind", "")) == LAST_MENU else LAST_FREE, "name": String(l.get("name", "")), "cells": lc}
	c.eaten = bool(src.get("eaten", false)) and c.pot.item_count() > 0
	return c
#endregion
