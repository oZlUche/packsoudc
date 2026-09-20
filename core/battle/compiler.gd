## 背包棋盘 → 战斗单位（架构文档 4.2）。
##
## [b]必须是纯函数[/b]：同样的棋盘永远编译出同样的 [CombatantSpec]。
## 玩家拖动物品时 UI 会实时重编译来显示预估 DPS，这是此类游戏的核心爽点；
## 回放、批量模拟与存档也全都依赖这一点。
##
## 五步，全部与遍历顺序无关：
## [codeblock]
## 1. 只收集棋盘上的非包物品（暂存区不参战，见 3.4）
## 2. 各物品写入基础值
## 3. 包体效果：按 bag_of() 聚合，施加给内容物
## 4. 邻接标记点亮：数每件物品的增益/受益格被几个【不同的】物品占住
## 5. 按 4.3 的数值约定结算，产出 abilities
## [endcodeblock]
class_name BattleCompiler
extends RefCounted

## run 级基础生命值。物品提供的 max_hp 在此之上叠加。
const BASE_HP := 25.0


## [param set_mods] 与 [param set_rules] 由 [SetTracker] 的 combat_mods() /
## combat_rules() 取出后传入。
##
## 编译器不认识 [SetTracker]，也不自己去数套装件数 —— 计数与激活是背包层的事，
## 物品一拖进棋盘就已经算好了（UI 要实时显示暗／亮）。这里只负责并入。
static func compile(
	board: GridInventory, base_hp: float = BASE_HP,
	set_mods: Array[StatModifier] = [] as Array[StatModifier],
	set_rules: Array[AbilityRule] = [] as Array[AbilityRule]
) -> CombatantSpec:
	var spec := CombatantSpec.new()
	if board == null:
		spec.max_hp = StatMath.from_float(base_hp)
		return spec

	# --- 1. 收集参战物品：棋盘上的非包物品，按 uid 升序 ---
	var fighters: Array[int] = []
	for inst in board.items():
		var item := inst as ItemInstance
		if item.def == null or board.acts_as_bag(item.def):
			continue
		fighters.append(item.uid)
	fighters.sort()

	# --- 2. 基础值 ---
	var stats: Dictionary = {}  # uid -> StatSet
	for uid in fighters:
		var set := StatSet.new()
		var def := board.get_item(uid).def
		if def.combat != null:
			def.combat.seed_stats(set)
		stats[uid] = set

	# --- 3. 包体效果施加给内容物 ---
	_apply_bag_effects(board, fighters, stats)

	# --- 4. 套装效果（战斗作用域）---
	for uid in fighters:
		for mod in set_mods:
			(mod as StatModifier).apply_to(stats[uid], 1)
	spec.set_rules.append_array(set_rules)

	# --- 5. 邻接标记 ---
	_apply_adjacency(board, fighters, stats)

	# --- 6. 产出 ---
	var hp := StatMath.from_float(base_hp)
	for uid in fighters:
		var set: StatSet = stats[uid]
		hp += set.total_of(BattleStats.MAX_HP)
		var def := board.get_item(uid).def
		var item := CompiledItem.new()
		item.source_uid = uid
		item.def_id = def.id
		item.stats = set
		if def.combat != null:
			item.rules = def.combat.rules.duplicate()
		spec.add(item)

	spec.max_hp = maxi(0, hp)
	return spec


## 包只作用于自己装着的东西。按 bag_of() 查归属，因此跨包摆放被禁止这条规则
## （3.2）在这里直接兑现为「每件物品的归属包唯一」。
static func _apply_bag_effects(board: GridInventory, fighters: Array[int], stats: Dictionary) -> void:
	for uid in fighters:
		var bag_uid := board.bag_of(uid)
		if bag_uid == GridInventory.EMPTY_UID:
			continue
		var bag := board.get_item(bag_uid)
		if bag == null or bag.def == null:
			continue
		for mod in bag.def.bag_mods:
			(mod as StatModifier).apply_to(stats[uid], 1)


static func _apply_adjacency(board: GridInventory, fighters: Array[int], stats: Dictionary) -> void:
	for uid in fighters:
		var holder := board.get_item(uid)
		var profile: AdjacencyProfile = holder.def.adjacency
		if profile == null:
			continue

		# 增益：站在这些格子上的邻居，各得一份
		if profile.has_grant():
			var receivers := _lit_neighbors(
				board, holder, profile.grant_cells, profile.grant_filter
			)
			for other in receivers:
				if not stats.has(other):
					continue  # 不参战的（比如包）跳过
				for mod in profile.grant_mods:
					(mod as StatModifier).apply_to(stats[other], 1)

		# 受益：点亮几个格，本物品就得几份
		if profile.has_receive():
			var lit := _lit_neighbors(
				board, holder, profile.receive_cells, profile.receive_filter
			).size()
			if lit > 0:
				for mod in profile.receive_mods:
					(mod as StatModifier).apply_to(stats[uid], lit)


## 占住指定标记格的邻居，**去重**后按 uid 升序返回。
##
## 去重直接来自「一件物品最多只能填另一件的一个格」这条规则：一件物品压住多个标记格
## 也只算一次。正因为是去重计数而不是匹配，结果才与遍历顺序无关。
## 排序只为调试时可读，对结果无影响。
static func _lit_neighbors(
	board: GridInventory,
	holder: ItemInstance,
	marker_cells: Array[Vector2i],
	filter: Array[StringName]
) -> Array[int]:
	var found: Array[int] = []
	var shape := holder.def.shape
	if shape == null:
		return found

	var seen := {}
	for offset in marker_cells:
		var cell := holder.origin + shape.transform_point(offset, holder.rotation)
		var other := board.cell_uid(cell)
		if other == GridInventory.EMPTY_UID or other == holder.uid or seen.has(other):
			continue
		var other_inst := board.get_item(other)
		if other_inst == null or not AdjacencyProfile.accepts(filter, other_inst.def):
			continue
		seen[other] = true
		found.append(other)
	found.sort()
	return found
