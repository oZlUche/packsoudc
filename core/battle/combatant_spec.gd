## 一个战斗单位的完整编译结果。[BattleSim] 只吃它，不碰背包。
class_name CombatantSpec
extends RefCounted

var max_hp: int = 0                  ## 定点
## 093（蛮神 4 级）：生命归零后还能坚持几秒；0 = 没有。
##
## 101 第 5 刀：原来是 `flags: Dictionary` 里的一个字符串键 —— 结算规则（不是效果）留在内核，但**按带类型的字段读**：
## 拼错键名不会再默默失效。写它的是 [UndyingPerk]，读它的是 [CombatantRuntime]
var undying_sec: float = 0.0

## 105：开战时就带着的标准轴层数（4.3）：轴 → 层数。来源是编译期的单位级增益
## （祈祷攒的火焰加成、将来的局内 / 局外 / 套装 / 技能）。[CombatantRuntime] 把它种进**系统层** ——
## 这一场的常驻加成，对手的净化洗不掉
var axes: Dictionary = {}

## 角色自带的基础属性（生命上限、耐力上限…），不属于任何道具。
## 为 null 时该单位没有任何自带属性 —— 手搓的测试假人就是这样。
var baseline: StatSet = null
## 按 source_uid 升序，顺序稳定
var items: Array[CompiledItem] = []

## 套装带来的规则。不属于任何物品，来源 uid 为 0，取属性时退回单位级。
var set_rules: Array[AbilityRule] = []

## 103 第 6 条：编译期并进来的外来加成（信仰阶、套装档位、局外 buff、技能被动），给 buff 栏画「常驻」格用；结算内核不读
var passives: Array[PassiveNote] = []

## 103 第 7 条：编译它的那张棋盘（回放画双方棋盘、盖冷却遮罩用；uid 就是日志里的 uid）。结算内核不读
var board: GridInventory = null
## 148：这一场站在别人装载格上（171 前是受益格）、真的供给了的道具（魔晶石）uid，升序。[WearModule] 按它扣耐久
var fed_uids: Array[int] = []
## 171：装载归属 —— 晶石 uid → 拿到它的法杖 uid（[method BattleCompiler.load_assignments]）。悬浮窗的装载行 / 「装在」读它
var loads: Dictionary = {}

var _by_uid: Dictionary = {}


func add(item: CompiledItem) -> void:
	items.append(item)
	_by_uid[item.source_uid] = item


func stats_of(uid: int) -> StatSet:
	var it: CompiledItem = _by_uid.get(uid, null)
	return it.stats if it != null else null


func item_of(uid: int) -> CompiledItem:
	return _by_uid.get(uid, null)


## uid → 显示名（回放把「uid 2 出手」写成「手枪 出手」）；[param spec] 为 null 返回空表。结算内核不读
static func item_names(spec: CombatantSpec, items: ItemDatabase) -> Dictionary:
	var out := {}
	if spec == null:
		return out
	for item in spec.items:
		var inst := spec.board.get_item(item.source_uid) if spec.board != null else null
		if inst != null and inst.def != null and inst.def.id == item.def_id:
			out[item.source_uid] = Names.of_item(inst)     # 148：棋盘上那一件的名字（魔晶石带前缀）
			continue
		var def := items.get_def(item.def_id)
		out[item.source_uid] = Names.of(def) if def != null else String(item.def_id)
	return out


## 有规则的物品
func active_items() -> Array[CompiledItem]:
	var out: Array[CompiledItem] = []
	for it in items:
		if it.is_active():
			out.append(it)
	return out


func max_hp_int() -> int:
	return StatMath.to_int(max_hp)


## 087：开战即上身、作用于自己的 buff 的属性修饰（开战时 + 必然 + apply_status 给自己）—— 血怒这类。
## 返回 [[StatModifier, 层数], …]。运行时 [CombatantRuntime] 会把 buff 的 mods 施加到每件道具的属性上，预估也照做，
## 否则护符的增伤在统计里看不见（作者问的：不是没生效，是统计没算）。buff 有时长也按全程算 —— 只是预估
func opening_mods() -> Array:
	var out: Array = []
	var pool: Array = []
	for it in items:
		pool.append_array(it.rules)
	pool.append_array(set_rules)
	for r in pool:
		var rule := r as AbilityRule
		if rule == null or not (rule.trigger is OnBattleStart) or not (rule.cadence == null or rule.cadence is Always):
			continue
		for e in rule.effects:
			var ap := e as ApplyStatus
			if ap == null or ap.buff == null or ap.target != CombatEffect.Target.SELF:
				continue
			for m in ap.buff.mods:
				out.append([m, maxi(1, ap.stacks)])
	return out


## 152：同一批开战 buff 带的标准轴层数（axis → 层数）。预估照运行时那样把它们当公式的最后一步
func opening_axes() -> Dictionary:
	var out: Dictionary = {}
	var pool: Array = []
	for it in items:
		pool.append_array(it.rules)
	pool.append_array(set_rules)
	for r in pool:
		var rule := r as AbilityRule
		if rule == null or not (rule.trigger is OnBattleStart) or not (rule.cadence == null or rule.cadence is Always):
			continue
		for e in rule.effects:
			var ap := e as ApplyStatus
			if ap == null or ap.buff == null or ap.target != CombatEffect.Target.SELF:
				continue
			for a in ap.buff.axes:
				if a != null:
					var k := (a as BuffAxis).axis
					out[k] = int(out.get(k, 0)) + (a as BuffAxis).stacks * maxi(1, ap.stacks)
	return out


## 一件道具算上开战 buff 之后的属性
func stats_with_opening(it: CompiledItem) -> StatSet:
	var mods := opening_mods()
	var axes := opening_axes()
	if (mods.is_empty() and axes.is_empty()) or it.stats == null:
		return it.stats
	var copy := it.stats.clone()
	for pair in mods:
		(pair[0] as StatModifier).apply_to(copy, int(pair[1]))
	for axis in axes:     # 152：和 [method CombatantRuntime._apply_axes] 同一种落法（只落属性轴）
		var key := StatAxes.stat_of(axis)
		if key == &"" or int(axes[axis]) == 0:
			continue
		if StatAxes.is_factor(axis):
			CombatantRuntime._scale_final(copy, key, StatAxes.factor(axis, int(axes[axis])))
		elif StatAxes.on_items(axis):
			copy.ensure(key).add_flat(StatMath.from_float(int(axes[axis]) * StatAxes.step_of(axis)))
	return copy


## 一件道具的预估 DPS（算上开战 buff）
func estimated_dps_of(it: CompiledItem) -> float:
	return it.estimated_dps(stats_with_opening(it))


func rough_dps() -> float:
	var total := 0.0
	for it in items:
		total += estimated_dps_of(it)
	return total


func _to_string() -> String:
	return "CombatantSpec(HP=%d, %d 件物品 / %d 件主动, 约 %.1f DPS)" % [
		max_hp_int(), items.size(), active_items().size(), rough_dps()
	]
