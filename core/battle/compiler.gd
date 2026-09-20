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
## 4. 插槽点亮：数每件物品的星/菱形被几个【不同的】物品占住
## 5. 按 4.3 的数值约定结算，产出 abilities
## [endcodeblock]
class_name BattleCompiler
extends RefCounted

## run 级基础生命值。物品提供的 max_hp 在此之上叠加。
const BASE_HP := 25.0


static func compile(board: GridInventory, base_hp: float = BASE_HP) -> CombatantSpec:
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

	# --- 4. 插槽点亮 ---
	_apply_sockets(board, fighters, stats)

	# --- 5. 产出 ---
	var hp := StatMath.from_float(base_hp)
	for uid in fighters:
		var set: StatSet = stats[uid]
		hp += set.total_of(BattleStats.MAX_HP)
		var def := board.get_item(uid).def
		if def.combat != null and def.combat.is_active:
			var ability := Ability.new()
			ability.source_uid = uid
			ability.def_id = def.id
			ability.stats = set
			spec.abilities.append(ability)

	spec.max_hp = maxi(0, hp)
	spec.item_stats = stats
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


static func _apply_sockets(board: GridInventory, fighters: Array[int], stats: Dictionary) -> void:
	for uid in fighters:
		var holder := board.get_item(uid)
		var sockets: SocketProfile = holder.def.sockets
		if sockets == null:
			continue
		if sockets.has_star():
			_resolve_socket(
				board, holder, stats,
				sockets.star_cells, sockets.star_filter,
				sockets.star_direction, sockets.star_mods
			)
		if sockets.has_diamond():
			_resolve_socket(
				board, holder, stats,
				sockets.diamond_cells, sockets.diamond_filter,
				sockets.diamond_direction, sockets.diamond_mods
			)


## 点亮一类插槽并施加效果。
##
## 计数方式是**去重**：一件物品压住多个插槽格也只算一次。这直接来自
## 「一件物品最多只能填另一件的一个星」这条规则，也让结果与遍历顺序无关。
static func _resolve_socket(
	board: GridInventory,
	holder: ItemInstance,
	stats: Dictionary,
	socket_cells: Array[Vector2i],
	filter: Array[StringName],
	direction: int,
	mods: Array[StatModifier]
) -> void:
	var shape := holder.def.shape
	if shape == null:
		return

	var fillers: Array[int] = []
	var seen := {}
	for offset in socket_cells:
		var cell := holder.origin + shape.transform_point(offset, holder.rotation)
		var other := board.cell_uid(cell)
		if other == GridInventory.EMPTY_UID or other == holder.uid or seen.has(other):
			continue
		var other_inst := board.get_item(other)
		if other_inst == null or not SocketProfile.accepts(filter, other_inst.def):
			continue
		seen[other] = true
		fillers.append(other)

	if fillers.is_empty():
		return
	fillers.sort()  # 顺序对结果无影响，排序只为调试时可读

	if direction == SocketProfile.Direction.HOLDER:
		# 持有者受益，份数 = 点亮数
		for mod in mods:
			(mod as StatModifier).apply_to(stats[holder.uid], fillers.size())
		return

	# 填充者受影响，各得一份。不在棋盘参战列表里的（比如包）跳过。
	for filler in fillers:
		if not stats.has(filler):
			continue
		for mod in mods:
			(mod as StatModifier).apply_to(stats[filler], 1)
