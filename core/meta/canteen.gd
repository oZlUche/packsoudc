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

static var _rules: CanteenRules = null

## 食材仓库
var store: GridInventory = null
## 锅：摆进去的算已经拿出仓库，拖回去回到仓库；出征成功时吃掉
var pot: GridInventory = null
## 旧档里已有的薄荷叶束、蜂蜜罐这类食材，开放那一刻从主仓库搬进食材仓库一次（[method GameFlow.sync_canteen]）
var moved_legacy := false


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


## 数字：整数不带小数点，带小数的留到两位（0.25）
static func num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, 2)
#endregion


#region 存档
func to_dict() -> Dictionary:
	return {"store": store.to_dict(), "pot": pot.to_dict(), "moved_legacy": moved_legacy}


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
	return c
#endregion
