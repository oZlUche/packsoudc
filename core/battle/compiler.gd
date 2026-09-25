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

## run 级基础生命值。保留给只关心生命的调用方；完整基线见 [CombatantBaseline]。
const BASE_HP := 25.0


## [param set_mods] 与 [param set_rules] 由 [SetTracker] 的 combat_mods() /
## combat_rules() 取出后传入。
##
## 编译器不认识 [SetTracker]，也不自己去数套装件数 —— 计数与激活是背包层的事，
## 物品一拖进棋盘就已经算好了（UI 要实时显示暗／亮）。这里只负责并入。
## [param baseline] 是角色自带的那份属性（生命上限、耐力上限…），
## 为 null 时用 [method CombatantBaseline.default_baseline]。
## 角色系统落地后由角色定义提供，编译器这里不用改。
## [param faith_tiers] 是信力（082）：信仰对象标签 → 现在第几阶；信仰道具上 tier ≤ 它的 [FaithBonus] 并进来。空表 = 一阶都没过。
## 仍是纯函数：同样的棋盘、同样的阶，永远同样的结果
static func compile(
	board: GridInventory, baseline: CombatantBaseline = null,
	set_mods: Array[StatModifier] = [] as Array[StatModifier],
	set_rules: Array[AbilityRule] = [] as Array[AbilityRule],
	faith_tiers: Dictionary = {}
) -> CombatantSpec:
	var base := baseline if baseline != null else CombatantBaseline.default_baseline()
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	base.seed_stats(spec.baseline)

	if board == null:
		spec.max_hp = spec.baseline.total_of(BattleStats.MAX_HP)
		return spec

	# --- 1. 收集参战物品：棋盘上的非包物品，按 uid 升序 ---
	# 信仰（8-4）：只激活最后置入的信仰道具所属的信仰，别的信仰的道具休眠 —— 不参战、不给邻接
	var active_faith := FaithState.active_tag(board)
	var fighters: Array[int] = []
	for inst in board.items():
		var item := inst as ItemInstance
		if item.def == null or board.acts_as_bag(item.def):
			continue
		if FaithState.is_dormant(item.def, active_faith):
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

	# --- 4b. 信力解锁的功能（082）：这件道具的信仰现在第几阶，tier 不超过它的加成并进来（规则在第 6 步收） ---
	var bonus_rules: Dictionary = {}  # uid -> Array[AbilityRule]
	for uid in fighters:
		var def := board.get_item(uid).def
		if not def.has_faith() or def.faith_bonuses.is_empty():
			continue
		var tier := int(faith_tiers.get(def.faith_tag(), 0))
		var extra: Array[AbilityRule] = []
		for b in def.faith_bonuses:
			var bonus := b as FaithBonus
			if bonus == null or bonus.tier > tier:
				continue
			for mod in bonus.mods:
				(mod as StatModifier).apply_to(stats[uid], 1)
			extra.append_array(bonus.rules)
		if not extra.is_empty():
			bonus_rules[uid] = extra

	# --- 5. 邻接标记。顺带记下连结关系，供 OnItemFired 的 LINKED 来源使用 ---
	var links: Dictionary = {}  # uid -> {uid: true}
	_apply_adjacency(board, fighters, stats, links)

	# --- 6. 产出 ---
	var hp := spec.baseline.total_of(BattleStats.MAX_HP)
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
		if bonus_rules.has(uid):
			item.rules.append_array(bonus_rules[uid])
		var linked: Array[int] = []
		for other in (links.get(uid, {}) as Dictionary).keys():
			linked.append(other)
		linked.sort()  # 顺序稳定，编译结果才可复现
		item.linked_uids = linked
		spec.add(item)

	spec.max_hp = maxi(0, hp)
	return spec


## 包只作用于自己**整件**装着的东西。横跨两个包的物品 bag_of() 为空，两边的加成都拿不到 ——
## 跨包是用空间换加成的取舍，不是双份加成的漏洞。按 bag_of() 查归属，这条规则
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


## [param links] 收集双向的连结关系：uid -> {对方 uid: true}。
##
## 连结是**对称**的 —— 「我给你加成」和「你给我加成」都算连着。
## 非对称会让内容作者踩坑：把配件贴在武器旁边，却只有一边听得见对方出手。
static func _apply_adjacency(
	board: GridInventory, fighters: Array[int], stats: Dictionary, links: Dictionary
) -> void:
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
				_link(links, uid, other)
				for mod in profile.grant_mods:
					(mod as StatModifier).apply_to(stats[other], 1)

		# 受益：点亮几个格，本物品就得几份
		if profile.has_receive():
			var providers := _lit_neighbors(
				board, holder, profile.receive_cells, profile.receive_filter
			)
			for other in providers:
				if stats.has(other):
					_link(links, uid, other)
			if not providers.is_empty():
				for mod in profile.receive_mods:
					(mod as StatModifier).apply_to(stats[uid], providers.size())


static func _link(links: Dictionary, a: int, b: int) -> void:
	if a == b:
		return
	if not links.has(a):
		links[a] = {}
	if not links.has(b):
		links[b] = {}
	links[a][b] = true
	links[b][a] = true


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
	if holder.def.shape == null:
		return found

	var seen := {}
	for cell in holder.absolute_cells(marker_cells):
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
