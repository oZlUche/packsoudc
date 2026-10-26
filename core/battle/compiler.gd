## 背包棋盘 + 这一场的外来加成 → 战斗单位（架构文档 4.2）。
##
## [b]必须是纯函数[/b]：同样的棋盘与同样的 [CompileInput] 永远编译出同样的 [CombatantSpec]。
## 玩家拖动物品时 UI 会实时重编译来显示预估 DPS，这是此类游戏的核心爽点；
## 回放、批量模拟与存档也全都依赖这一点。按件随机挑选（[ScopedMod.pick]）也在这一句之内 ——
## 随机只由 [member CompileInput.seed] 决定，编译器不自己造随机、不认识 [RunState]。
##
## 105：战斗单位**只有这一个来源**。信仰的 8 条效果以前是编译完再 `modify_spec(spec)` 改一遍，
## 现在一律翻译成 [CompileInput] 的字段，由这里并进来。
##
## 九步，全部与遍历顺序无关：
## [codeblock]
## 1  只收集棋盘上的非包物品（地上不参战，见 3.4）
## 2  各物品写入基础值                       ← base 只在这里写，和第 7 步的 base_scale
## 3  包体效果：按 bag_of() 聚合，施加给内容物
## 4  整单位的修饰（套装、一局 buff）：input.mods → 每件
## 4b 信力解锁的功能：这件道具的信仰现在第几阶；生长（207）：这件长到了第几阶
## 5  邻接标记点亮：数每件物品的增益/受益格被几个【不同的】物品占住
## 6  打包 CompiledItem（先不算 max_hp）
## 7  按件：input.scoped 逐条筛一批件，加修饰 / 缩放基础值 / 挂规则
## 8  整单位：基线修饰、单位级规则、开战时的轴层数、结算旗子
## 9  max_hp = 基线生命 + Σ 每件生命        ← 最后算，所以改基线的不用再手工补账
## [endcodeblock]
class_name BattleCompiler
extends RefCounted


## 薄的兼容入口：只关心棋盘与这几样的调用方（大多是测试与敌人 kit）用它，内部造一份 [CompileInput]。
## 正式的玩家编译走 [method compile] + 完整的 [CompileInput]（信仰效果、轴、按件修饰都在里面）
static func compile_board(
	board: GridInventory, baseline: CombatantBaseline = null,
	set_mods: Array[StatModifier] = [] as Array[StatModifier],
	set_rules: Array[AbilityRule] = [] as Array[AbilityRule],
	faith_tiers: Dictionary = {}, faith_points: Dictionary = {}
) -> CombatantSpec:
	return compile(board, CompileInput.of(baseline, set_mods, set_rules, faith_tiers, faith_points))


## [param input] 装齐这一场的全部外来加成（套装、一局 buff、信力、信仰效果、轴的初值）。
##
## 编译器不认识 [SetTracker]，也不自己去数套装件数 —— 计数与激活是背包层的事，
## 物品一拖进棋盘就已经算好了（UI 要实时显示暗／亮）。这里只负责并入。
static func compile(board: GridInventory, input: CompileInput = null) -> CombatantSpec:
	var inp := input if input != null else CompileInput.new()
	var base := inp.baseline if inp.baseline != null else CombatantBaseline.default_baseline()
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	base.seed_stats(spec.baseline)
	spec.axes = inp.axes.duplicate()
	spec.undying_sec = inp.undying_sec
	spec.immune_buffs = inp.immune_buffs.duplicate()     # 210

	# --- 1. 收集参战物品：棋盘上的非包物品，按 uid 升序 ---
	# 信仰（8-4）：只激活最后置入的信仰道具所属的信仰，别的信仰的道具休眠。
	# 087（作者定）：休眠的仍可能有**通用效果**（盾的固定减伤、武器的攻击力 = 它自己的 combat）：留着的照样参战，
	# 只丢信力加成与邻接（`dormant` 记着谁是休眠的）；不留的（护符）彻底不参战
	# 140：没有棋盘（敌人基线、测试）只跳过这一段 —— 后面几步对着空的 fighters 自然什么都不做，九步只有一条路
	# 212：魔兽的棋盘不认信仰（身上本来就没有信仰道具；不让 is_dormant 去猜）
	var active_faith := FaithState.active_tag(board) if board != null and not inp.wild else &""
	var fighters: Array[int] = []
	var dormant: Dictionary = {}     # uid -> true
	for inst in (board.items() if board != null else []):
		var item := inst as ItemInstance
		if item.def == null or board.acts_as_bag(item.def):
			continue
		# 2026-10-22（作者）：标了「不参战」的不进 fighters —— 东西还在棋盘上（占格、能拖），只是这一场不算它
		if item.is_benched():
			continue
		if not inp.wild and FaithState.is_dormant(item.def, active_faith):
			if not FaithState.keeps_combat_when_dormant(item.def):
				continue
			dormant[item.uid] = true
		fighters.append(item.uid)
	fighters.sort()

	# --- 2. 基础值 ---
	var stats: Dictionary = {}  # uid -> StatSet
	for uid in fighters:
		var set := StatSet.new()
		var profile := profile_of(board.get_item(uid).def, inp.wild)
		if profile != null:
			profile.seed_stats(set)
		stats[uid] = set

	# --- 3. 包体效果施加给内容物 ---
	_apply_bag_effects(board, fighters, stats)

	# --- 4. 整单位的修饰：套装与一局 buff 给每一件参战道具（规则在第 8 步收）---
	for uid in fighters:
		for mod in inp.mods:
			(mod as StatModifier).apply_to(stats[uid], 1)

	# --- 4b. 信力解锁的功能（082）：这件道具的信仰现在第几阶，tier 不超过它的加成并进来（规则在第 6 步收） ---
	var bonus_rules: Dictionary = {}  # uid -> Array[AbilityRule]
	for uid in fighters:
		var def := board.get_item(uid).def
		if inp.wild or not def.has_faith() or def.faith_bonuses.is_empty() or dormant.has(uid):
			continue
		var tier := int(inp.faith_tiers.get(def.faith_tag(), 0))
		var pts := int(inp.faith_points.get(def.faith_tag(), 0))
		var extra: Array[AbilityRule] = []
		for b in def.faith_bonuses:
			var bonus := b as FaithBonus
			if bonus == null:
				continue
			var times := bonus.times_for(tier, pts)     # 095：按阶 / 激活即 / 按信力几份
			if times <= 0:
				continue
			for mod in bonus.mods:
				(mod as StatModifier).apply_to(stats[uid], times)
			extra.append_array(bonus.rules)
		if not extra.is_empty():
			bonus_rules[uid] = extra

	# --- 4b'. 生长（207）：长到第几阶记在实例上，取当前阶那一份（不累加）+ 抽中的额外效果；休眠的不算 ---
	for uid in fighters:
		var inst := board.get_item(uid)
		if inst.def.growth == null or dormant.has(uid):
			continue
		var st := GrowthProfile.current(inst)
		if st == null:
			continue
		var grown: Array[AbilityRule] = []
		for mod in st.mods:
			(mod as StatModifier).apply_to(stats[uid], 1)
		grown.append_array(st.rules)
		for gb in GrowthProfile.bonuses_of(inst):
			for mod in gb.mods:
				(mod as StatModifier).apply_to(stats[uid], 1)
			grown.append_array(gb.rules)
		if not grown.is_empty():
			var merged: Array[AbilityRule] = []
			merged.append_array(bonus_rules.get(uid, [] as Array[AbilityRule]))
			merged.append_array(grown)
			bonus_rules[uid] = merged

	# --- 5. 邻接标记。顺带记下连结关系，供 OnItemFired 的 LINKED 来源使用 ---
	var links: Dictionary = {}  # uid -> {uid: true}
	var social: Array[int] = []     # 参与邻接的：休眠的不给也不收
	for uid in fighters:
		if not dormant.has(uid) and not inp.wild:     # 212：魔兽的棋盘不跑邻接
			social.append(uid)
	var attach_pending: Dictionary = {}     # uid -> [[rule, origin], ...]（108：邻居给我挂的规则，第 6 步打包时挂上）
	var fed: Dictionary = {}     # 148：这一场真的供给了的（魔晶石点亮了法杖）uid -> true，耐久按它扣
	spec.loads = _apply_adjacency(board, social, stats, links, attach_pending, fed)
	var fed_list: Array[int] = []
	for f in fed:
		fed_list.append(int(f))
	fed_list.sort()
	spec.fed_uids = fed_list

	# --- 6. 打包 ---
	for uid in fighters:
		var set: StatSet = stats[uid]
		var def := board.get_item(uid).def
		var item := CompiledItem.new()
		item.source_uid = uid
		item.def_id = def.id
		item.tags = def.tags.duplicate()
		item.stats = set
		var profile := profile_of(def, inp.wild)
		if profile != null:
			item.rules = profile.rules.duplicate()
		if bonus_rules.has(uid):
			item.rules.append_array(bonus_rules[uid])
		for pair in attach_pending.get(uid, []):
			_attach(item, pair[0], pair[1])
		# 175 补充五：道具自己的「造成伤害后施加」简写，也走附加入口（来源是道具自己 → 直接来源，130 的「施加时」听得到）
		var applies := def.wild_applies if inp.wild else def.applies     # 212：魔兽咬人施加的是 wild_applies
		if not applies.is_empty():
			_attach(item, ElementApply.rule_of(applies), ElementApply.ORIGIN)
		# 175 第三批：附魔（铸牌附上的覆盖预置的）走同一个附加入口，一把只挂一条；表里查不到了就不挂
		var ench := Forge.enchant_of(board.get_item(uid))
		if not ench.is_empty():
			_attach(item, Forge.rule_of(ench), Forge.ORIGIN)
		var linked: Array[int] = []
		for other in (links.get(uid, {}) as Dictionary).keys():
			linked.append(other)
		linked.sort()  # 顺序稳定，编译结果才可复现
		item.linked_uids = linked
		item.loaded = cycle_order(board, uid, spec.loads)
		if not item.loaded.is_empty():
			set.ensure(BattleStats.LOAD_STEPS).base = item.loaded.size() * StatMath.ONE     # 175：一轮几下，[CycleCadence] 读它
		spec.add(item)

	# --- 7. 按件（105 3.2）---
	_apply_scoped(spec, board, inp)

	# --- 8. 整单位 ---
	_apply_baseline_mods(spec, inp)
	spec.set_rules.append_array(inp.rules)

	# --- 9. 生命上限。放在最后，所以第 8 步改基线生命的不用再手工补一遍 ---
	var hp := spec.baseline.total_of(BattleStats.MAX_HP)
	for it in spec.items:
		hp += (it as CompiledItem).stats.total_of(BattleStats.MAX_HP)
	spec.max_hp = maxi(0, hp)
	spec.board = board
	return spec


## 212：这件道具这一边用哪份战斗定义 —— 魔兽持有（[param wild]）且写了 `wild` 就用它，否则 `combat`
static func profile_of(def: ItemDef, wild: bool) -> CombatProfile:
	if def == null:
		return null
	return def.wild if wild and def.wild != null else def.combat


## 第 7 步：按件修饰。逐条按下标顺序 —— 随机挑选的种子里带着下标，所以两条都挑 3 把时挑的不是同一批
static func _apply_scoped(spec: CombatantSpec, board: GridInventory, inp: CompileInput) -> void:
	for i in inp.scoped.size():
		var scope := inp.scoped[i] as ScopedMod
		if scope == null or scope.is_empty():
			continue
		var hits: Array[int] = []
		for it in spec.items:
			var item := it as CompiledItem
			var inst := board.get_item(item.source_uid)
			if inst != null and scope.matches(inst.def, item.is_active()):
				hits.append(item.source_uid)
		hits.sort()     # 候选按 uid 升序：挑的结果只由 seed 与候选集决定
		for uid in scope.choose(hits, hash("%d:scoped:%d" % [inp.seed, i])):
			_apply_scope_to(spec.item_of(uid), scope)


static func _apply_scope_to(item: CompiledItem, scope: ScopedMod) -> void:
	if item == null:
		return
	for mod in scope.mods:
		(mod as StatModifier).apply_to(item.stats, 1)
	if not is_equal_approx(scope.base_scale, 1.0):
		for key in item.stats.keys():
			var k := StringName(String(key))
			if scope.scales(k):
				var v := item.stats.ensure(k)
				v.base = roundi(float(v.base) * scope.base_scale)
	for r in scope.rules:
		_attach(item, r as AbilityRule, scope.origin)


## 108（作者定）：**附加规则的唯一入口** —— 把 [param rule] 挂到宿主 [param item] 上：深拷贝、把 [OnItemFired] 绑成只听宿主、记来源。
## 邻接的增益规则（[member AdjacencyProfile.grant_rules]）和按件修饰（[member ScopedMod.rules]，日神附魔）都从这里进。
## 挂上去之后它就是宿主的一条规则：以宿主身份跑（`item_stat` 读宿主、伤害来源是宿主 → 直接伤害，106 §八）
static func _attach(item: CompiledItem, rule: AbilityRule, origin: StringName) -> void:
	if item == null or rule == null:
		return
	var copy := rule.duplicate(true) as AbilityRule
	# 挂到单件上的规则里的「有道具出手」绑成只听宿主 —— 否则一件附魔会被全场出手都触发
	if copy.trigger is OnItemFired:
		var trig := copy.trigger as OnItemFired
		trig.include_self = true
		trig.source_uids = [item.source_uid] as Array[int]
	item.rules.append(copy)
	if origin != &"":
		item.attached.append({"rule_index": item.rules.size() - 1, "origin": origin})


## 第 8 步：基线修饰（食物护甲、`stat_mod(baseline)`）
static func _apply_baseline_mods(spec: CombatantSpec, inp: CompileInput) -> void:
	for mod in inp.baseline_mods:
		(mod as StatModifier).apply_to(spec.baseline, 1)


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
	board: GridInventory, fighters: Array[int], stats: Dictionary, links: Dictionary,
	attach_pending: Dictionary, fed: Dictionary = {}
) -> Dictionary:
	for uid in fighters:
		var holder := board.get_item(uid)
		var profile: AdjacencyProfile = GrowthProfile.adjacency_of(holder)     # 256：军功牌的增益圈跟着阶走
		if profile == null:
			continue

		# 增益：站在这些格子上的邻居，各得一份
		if profile.has_grant():
			var receivers := _lit_neighbors(
				board, holder, profile.grant_cells, profile.grant_filter, profile.grant_filter_all
			)
			for other in receivers:
				if not stats.has(other):
					continue  # 不参战的（比如包）跳过
				_link(links, uid, other)
				for mod in profile.grant_mods:
					(mod as StatModifier).apply_to(stats[other], 1)
				for r in profile.grant_rules:     # 108：规则等第 6 步宿主打包好再挂（holder 按 uid 升序，挂的顺序稳定）
					if r != null:
						if not attach_pending.has(other):
							attach_pending[other] = []
						attach_pending[other].append([r, holder.def.id])

		# 受益：点亮几个格，本物品就得几份
		if not profile.receive_cells.is_empty():
			var providers := _lit_neighbors(
				board, holder, profile.receive_cells, profile.receive_filter
			)
			if profile.has_receive():
				for other in providers:
					if stats.has(other):
						_link(links, uid, other)
				if not providers.is_empty():
					for mod in profile.receive_mods:
						(mod as StatModifier).apply_to(stats[uid], providers.size())
				for other in providers:     # 132：每个点亮的邻居给本件挂一份受益规则，来源记邻居
					var giver := board.get_item(other)
					for r in profile.receive_rules:
						if r != null and giver != null:
							if not attach_pending.has(uid):
								attach_pending[uid] = []
							attach_pending[uid].append([r, giver.def.id])
	# 148 / 171 供给：装载格上的晶石把自己带的「给宿主的东西」交给宿主。一颗晶石只给一把（[method load_assignments]）；一把一颗一份；用坏了的不给
	var social := {}
	for uid in fighters:
		social[uid] = true
	var loads := load_assignments(board, social)
	var crystals := loads.keys()
	crystals.sort()
	for other in crystals:
		var uid: int = loads[other]
		var feeder := board.get_item(other)
		var fp: AdjacencyProfile = feeder.def.adjacency
		_link(links, uid, other)
		fed[other] = true
		var cycler := is_cycler(board.get_item(uid).def)
		for mod in fp.feed_mods:
			if cycler and (mod as StatModifier).stat == BattleStats.DAMAGE:
				continue     # 175：轮读的法杖，晶石的伤害只在轮到它那一下加（[member CompiledItem.loaded]）
			(mod as StatModifier).apply_to(stats[uid], 1)
		for r in fp.feed_rules:
			if r != null:
				if cycler and (convert_to(r) != &"" or not applies_of(r).is_empty()):
					continue     # 175：换型也一样，轮到它那一下才换；补充五：施加元素也是，轮到它那一下才施加
				if not attach_pending.has(uid):
					attach_pending[uid] = []
				attach_pending[uid].append([r, feeder.def.id])
	return loads


## 175：规则里有 [FireLoaded] 的宿主 —— 晶石的伤害与换型按轮次用，不常驻
static func is_cycler(def: ItemDef) -> bool:
	if def == null or def.combat == null:
		return false
	for r in def.combat.rules:
		for e in (r as AbilityRule).effects:
			if e is FireLoaded:
				return true
	return false


## 175：一条供给规则若是「受伤前把我的伤害换成某型」，返回那个类型；不是 = 空
static func convert_to(rule: AbilityRule) -> StringName:
	if rule == null:
		return &""
	for e in rule.effects:
		if e is ConvertDamageType:
			return (e as ConvertDamageType).to
	return &""


## 175 补充五：一条供给规则若是「这件造成伤害后施加某个状态」（on_damage DEALT + [ApplyStatus]），返回 `{buff: id, stacks}`；不是 = 空。
## 轮读的法杖把它记进轮读表（[member CompiledItem.loaded] 每颗的 `applies`），轮到那颗才施加
static func applies_of(rule: AbilityRule) -> Dictionary:
	if rule == null or not (rule.trigger is OnDamage) or (rule.trigger as OnDamage).direction != DamageTrigger.Direction.DEALT:
		return {}
	for e in rule.effects:
		if e is ApplyStatus and (e as ApplyStatus).buff != null:
			return {"buff": (e as ApplyStatus).buff.id, "stacks": maxi(1, (e as ApplyStatus).stacks)}
	return {}


## 175（作者定，待定 6 推荐 A）：法杖 [param holder_uid] 的轮读表 —— 归属给它的晶石按**顺时针**排：
## 以法杖占格的中心为原点，晶石压在装载格上那几格的中心为方位，从 12 点起顺时针；同角按 `placed_seq`、再按 uid。
## 每颗 `{uid, id, type, damage, applies}`（见 [member CompiledItem.loaded]；applies 空 = 这颗只打伤害、不施加）。宿主不轮读 / 没有晶石 = 空
static func cycle_order(board: GridInventory, holder_uid: int, loads: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var holder := board.get_item(holder_uid) if board != null else null
	if holder == null or not is_cycler(holder.def) or holder.def.adjacency == null:
		return out
	var center := _centroid(_abs_cells(holder))
	var slots := {}
	for c in holder.absolute_cells(holder.def.adjacency.load_cells):
		slots[c] = true
	var keyed: Array = []
	for other in loads:
		if int(loads[other]) != holder_uid:
			continue
		var feeder := board.get_item(other)
		var on: Array[Vector2i] = []
		for c in _abs_cells(feeder):
			if slots.has(c):
				on.append(c)
		var d := _centroid(on) - center
		var ang := fposmod(atan2(d.x, -d.y), TAU)
		keyed.append([roundi(ang * 1000000.0), feeder.placed_seq, int(other)])
	keyed.sort()
	for k in keyed:
		out.append(_loaded_entry(board.get_item(int(k[2]))))
	return out


static func _loaded_entry(feeder: ItemInstance) -> Dictionary:
	var fp: AdjacencyProfile = feeder.def.adjacency
	var dmg := StatSet.new()
	for mod in fp.feed_mods:
		if (mod as StatModifier).stat == BattleStats.DAMAGE:
			(mod as StatModifier).apply_to(dmg, 1)
	var type := &""
	var applies := {}
	for r in fp.feed_rules:
		var to := convert_to(r as AbilityRule)
		if to != &"":
			type = to
		var app := applies_of(r as AbilityRule)
		if not app.is_empty():
			applies = app
	return {"uid": feeder.uid, "id": feeder.def.id, "type": type if type != &"" else DamageTypes.PHYSICAL, "damage": dmg.total_of(BattleStats.DAMAGE),
		"applies": applies}


static func _abs_cells(inst: ItemInstance) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in inst.cells():
		out.append(inst.origin + c)
	return out


static func _centroid(cells: Array[Vector2i]) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c) + Vector2(0.5, 0.5)
	return sum / cells.size()


## 171（作者定）：装载归属 —— 晶石 uid → 法杖 uid。每颗（有供给、没碎、命中法杖的 load_filter，法杖命中它的 feed_filter）
## 压着几把法杖的装载格，只给 `placed_seq` 最大的那把（**后来者优先**；一样大按 uid 大的）。没压着任何一把的不在表里。
## 编译、悬浮窗（法杖的装载行、晶石的「装在」）都查它，所以永远说同一句话
## [param only]：只算这些 uid（编译时 = 参与邻接的；空 = 棋盘上全部）
static func load_assignments(board: GridInventory, only: Dictionary = {}) -> Dictionary:
	var out := {}
	if board == null:
		return out
	var best := {}     # 晶石 uid → 目前给的那把法杖
	for item in board.items():
		var holder := item as ItemInstance
		var profile: AdjacencyProfile = holder.def.adjacency if holder.def != null else null
		if profile == null or not profile.has_load() or (not only.is_empty() and not only.has(holder.uid)):
			continue
		for other in _lit_neighbors(board, holder, profile.load_cells, profile.load_tags()):
			if not only.is_empty() and not only.has(other):
				continue
			var feeder := board.get_item(other)
			var fp: AdjacencyProfile = feeder.def.adjacency if feeder != null and feeder.def != null else null
			if fp == null or not fp.has_feed() or feeder.is_broken() or not AdjacencyProfile.accepts(fp.feed_filter, holder.def):
				continue
			var cur: ItemInstance = best.get(other, null)
			if cur == null or holder.placed_seq > cur.placed_seq or (holder.placed_seq == cur.placed_seq and holder.uid > cur.uid):
				best[other] = holder
	for other in best:
		out[other] = (best[other] as ItemInstance).uid
	return out


## 171：压着这颗晶石的所有法杖（装载格上、互相接受），不管最后给了谁。悬浮窗写「另一把的装载槽也压着」用
static func load_claimants(board: GridInventory, crystal_uid: int) -> Array[int]:
	var out: Array[int] = []
	var feeder := board.get_item(crystal_uid) if board != null else null
	var fp: AdjacencyProfile = feeder.def.adjacency if feeder != null and feeder.def != null else null
	if fp == null or not fp.has_feed():
		return out
	for item in board.items():
		var holder := item as ItemInstance
		var profile: AdjacencyProfile = holder.def.adjacency if holder.def != null else null
		if profile == null or not profile.has_load() or not AdjacencyProfile.accepts(fp.feed_filter, holder.def):
			continue
		if _lit_neighbors(board, holder, profile.load_cells, profile.load_tags()).has(crystal_uid):
			out.append(holder.uid)
	out.sort()
	return out


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
	filter: Array[StringName],
	filter_all: Array[StringName] = []
) -> Array[int]:
	var found: Array[int] = []
	if holder.def.shape == null:
		return found

	var seen := {}
	var active: StringName = &"?"     # 还没查过
	for cell in holder.absolute_cells(marker_cells):
		var other := board.cell_uid(cell)
		if other == GridInventory.EMPTY_UID or other == holder.uid or seen.has(other):
			continue
		var other_inst := board.get_item(other)
		# 244：标了「不参战」= 不在场，既不给邻接也不受；补充一（作者 08:15）：休眠的也视为不存在
		#（留着通用效果的自己照打，对别人等于没有）。当前信仰只在碰到信仰道具时才查
		if other_inst == null or other_inst.is_benched() or not AdjacencyProfile.accepts(filter, other_inst.def) or not AdjacencyProfile.accepts_all(filter_all, other_inst.def):
			continue
		if other_inst.def.has_faith():
			if active == &"?":
				active = FaithState.active_tag(board)
			if FaithState.is_dormant(other_inst.def, active):
				continue
		seen[other] = true
		found.append(other)
	found.sort()
	return found
