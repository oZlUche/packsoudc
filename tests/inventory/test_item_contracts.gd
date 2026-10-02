## 道具契约测试：**作者数据说了什么，游戏里就得真的是什么**。
##
## [b]期望值全部从数据里推出来，一个都不写死。[/b] 这些用例跑在
## `data/authoring/items/*.json` 上，而那是作者（包括 MOD 作者）随时会改的东西 ——
## 写死「弹匣有两个增益格」意味着别人调个数测试就红一次，红得毫无信息量，
## 最后只会被无视。（这个毛病已经犯过两次：写死资产件数、写死增益格数量。）
##
## 所以这里测的不是「数值对不对」，而是**声明与效果是否一致**：
##
## [codeblock]
## 配了 base_stats        → 编译出来的属性就得是那个值
## 配了 max_xxx           → 战斗里就得有 xxx 这种资源
## 配了自发规则           → 打起来就得真的出手
## 配了增益格             → 站上去的邻居属性就得真的变
## 配了受益格             → 自己的属性就得真的变
## 配了战利品效果         → 掉落上下文就得真的被改到
## [endcodeblock]
##
## 新增道具自动进入覆盖范围，改数值不会让任何一条红 —— 这正是它该有的样子。
extends RefCounted

const BOARD := Vector2i(14, 14)
## 把道具摆在中间，标记格往哪边伸都不会出界
const CENTER := Vector2i(5, 5)
## 对照位置：离得足够远，任何标记格都够不着。用绝对坐标而不是 CENTER + 偏移 ——
## 后者算出来可能出界，然后「摆不下」被误报成测试失败（踩过一次）。
const FAR := Vector2i(12, 12)


#region 读数据
## 从作者数据读，而不是从 .tres —— 这样连导入这一段也一起测了
static func _load_all(t: TestCase) -> Array:
	var out: Array = []
	var dir := DirAccess.open(ContentPaths.AUTHORING_ITEMS)
	if dir == null:
		t.check(false, "打不开 " + ContentPaths.AUTHORING_ITEMS)
		return out
	var files := dir.get_files()
	files.sort()  # 顺序稳定，失败信息才可复现
	var ctx := ContentImporter.Context.new()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		var parsed = JSON.parse_string(
			FileAccess.get_file_as_string(ContentPaths.AUTHORING_ITEMS + "/" + f))
		if not (parsed is Dictionary):
			t.check(false, "%s 不是合法 JSON" % f)
			continue
		var report := ImportReport.new()
		report.source = id
		var def := ContentImporter.import_item(parsed, ctx, report)
		if not report.ok():
			t.check(false, "%s 导入失败：%s" % [id, report.to_text()])
			continue
		out.append(def)
	return out
#endregion


#region 棋盘 helper
static func _big_bag() -> ItemDef:
	var d := ItemDef.new()
	d.id = &"__test_bag"
	var rows: Array[String] = []
	for y in BOARD.y:
		rows.append("1".repeat(BOARD.x))
	d.shape = ItemShape.from_bits("\n".join(rows))
	d.is_bag = true
	return d


static func _board() -> GridInventory:
	var b := GridInventory.new(BOARD, 1, true)
	b.place(ItemInstance.create(_big_bag()), Vector2i.ZERO, 0)
	return b


## 给足资源的基线：不让「耐力不够」这类事掩盖掉「规则本身没接上」。
##
## 需要哪些资源也是**从数据里推**的 —— 扫一遍规则的消耗，用到什么就给什么。
static func _generous_baseline(def: ItemDef) -> CombatantBaseline:
	var b := CombatantBaseline.new()
	b.base_stats = {"max_hp": 9999.0}
	if def.combat != null:
		for rule in def.combat.rules:
			for cost in (rule as AbilityRule).costs:
				if cost is ResourceCost:
					b.base_stats["max_" + String((cost as ResourceCost).resource_key)] = 9999.0
	return b


static func _dummy(hp: float = 99999.0) -> CombatantSpec:
	var spec := CombatantSpec.new()
	spec.baseline = StatSet.new()
	spec.baseline.set_base(BattleStats.MAX_HP, StatMath.from_float(hp))
	spec.max_hp = spec.baseline.total_of(BattleStats.MAX_HP)
	return spec
#endregion


static func run(t: TestCase) -> void:
	t.begin("道具契约 · 属性与资源")

	for def in _load_all(t):
		var item := def as ItemDef
		if item.combat == null or item.combat.base_stats.is_empty():
			continue

		var board := _board()
		var inst := ItemInstance.create(item)
		if not board.place(inst, CENTER, 0):
			t.check(false, "%s 放不进测试棋盘" % item.id)
			continue
		if board.acts_as_bag(item):
			continue  # 包不参战，属性不进编译结果

		var spec := BattleCompiler.compile(board, _generous_baseline(item))
		var stats := spec.stats_of(inst.uid)
		t.not_null(stats, "%s 参战了" % item.id)
		if stats == null:
			continue

		# --- 声明的每一项基础属性都要原样出现在编译结果里 ---
		for key in item.combat.base_stats:
			var declared := float(item.combat.base_stats[key])
			var actual := StatMath.to_float(stats.total_of(StringName(key)))
			t.check(is_equal_approx(actual, declared),
				"%s 的 %s：配的是 %.2f，编译出来是 %.2f" % [item.id, key, declared, actual])

		# --- max_xxx 必须派生出 xxx 资源 ---
		var rt := CombatantRuntime.from_spec(spec, 0)
		for key in item.combat.base_stats:
			var res := BattleStats.resource_of_max(StringName(key))
			if res == &"":
				continue
			t.check(rt.resources.has(res),
				"%s 配了 %s，战斗里就该有 %s 这种资源" % [item.id, key, res])


static func run_rules_fire(t: TestCase) -> void:
	t.begin("道具契约 · 自发规则真的会出手")

	# 只看自发型（OnSchedule）：事件型要别的东西先动起来，单件道具测不了。
	for def in _load_all(t):
		var item := def as ItemDef
		if item.combat == null or item.combat.rules.is_empty():
			continue
		var self_driven := 0
		for rule in item.combat.rules:
			if (rule as AbilityRule).trigger is OnSchedule:
				self_driven += 1
		if self_driven == 0:
			continue

		var board := _board()
		var inst := ItemInstance.create(item)
		board.place(inst, CENTER, 0)
		if board.acts_as_bag(item):
			continue

		var spec := BattleCompiler.compile(board, _generous_baseline(item))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var result := BattleSim.run(spec, _dummy(), rng, 30.0)

		var fired := 0
		for e in result.log:
			var ev := e as BattleEvent
			if ev.name == BattleEvent.ITEM_FIRED and ev.get_int(&"uid") == inst.uid:
				fired += 1
		t.check(fired > 0,
			"%s 有 %d 条自发规则，30 秒里却一次都没出手（资源是管够的）"
				% [item.id, self_driven])


static func run_adjacency_grant(t: TestCase) -> void:
	t.begin("道具契约 · 增益格真的加到邻居身上")

	for def in _load_all(t):
		var item := def as ItemDef
		if item.adjacency == null or not item.adjacency.has_grant():
			continue

		# 造一个刚好符合过滤器的邻居，属性从 mods 里推：
		# 改哪一项就给它种哪一项，否则加成落在一个不存在的属性上，看不出差别
		var neighbor := _synthetic_neighbor(item.adjacency.grant_filter,
			item.adjacency.grant_mods)
		var cell: Vector2i = item.adjacency.grant_cells[0]

		var near := _compile_pair(item, neighbor, CENTER + cell)
		var far := _compile_pair(item, neighbor, FAR)
		if near.is_empty() or far.is_empty():
			t.check(false, "%s 的增益格测试摆不下（格子 %s）" % [item.id, cell])
			continue

		var changed := false
		for mod in item.adjacency.grant_mods:
			var key := (mod as StatModifier).stat
			if near["neighbor"].total_of(key) != far["neighbor"].total_of(key):
				changed = true
		t.check(changed,
			"%s 的增益格 %s：邻居站上去属性没有任何变化" % [item.id, cell])


static func run_adjacency_receive(t: TestCase) -> void:
	t.begin("道具契约 · 受益格真的加到自己身上")

	for def in _load_all(t):
		var item := def as ItemDef
		if item.adjacency == null or not item.adjacency.has_receive():
			continue

		var neighbor := _synthetic_neighbor(item.adjacency.receive_filter, [])
		var cell: Vector2i = item.adjacency.receive_cells[0]

		var near := _compile_pair(item, neighbor, CENTER + cell)
		var far := _compile_pair(item, neighbor, FAR)
		if near.is_empty() or far.is_empty():
			t.check(false, "%s 的受益格测试摆不下（格子 %s）" % [item.id, cell])
			continue

		var changed := false
		for mod in item.adjacency.receive_mods:
			var key := (mod as StatModifier).stat
			if near["self"].total_of(key) != far["self"].total_of(key):
				changed = true
		t.check(changed,
			"%s 的受益格 %s：邻居站上去自己的属性没有任何变化" % [item.id, cell])


static func run_loot_effects(t: TestCase) -> void:
	t.begin("道具契约 · 战利品效果真的改到上下文")

	for def in _load_all(t):
		var item := def as ItemDef
		var loot: Array[Effect] = []
		for e in item.effects:
			if (e as Effect).scope() == EffectScope.LOOT:
				loot.append(e)
		if loot.is_empty():
			continue

		var ctx := LootContext.new()
		var before := ctx.snapshot()
		for e in loot:
			(e as LootEffect).modify(ctx)
		t.check(ctx.snapshot() != before,
			"%s 配了 %d 条战利品效果，却一条都没改到掉落上下文" % [item.id, loot.size()])


#region 合成邻居
## 造一个符合过滤器、且带着被加成属性的邻居。
##
## 属性从 mods 里推：加成落在哪一项就给它种哪一项。种错了的话，
## 百分比加成会作用在一个不存在的属性上 —— 前后都是 0，测试看不出差别，
## 于是永远通过，也就永远测不出东西。
static func _synthetic_neighbor(filter: Array[StringName], mods: Array[StatModifier]) -> ItemDef:
	var d := ItemDef.new()
	d.id = &"__test_neighbor"
	d.shape = ItemShape.from_bits("1")
	var tags: Array[StringName] = []
	if not filter.is_empty():
		tags.append(filter[0])
	d.tags = tags

	var c := CombatProfile.new()
	var seeded := {"damage": 10.0}
	for mod in mods:
		seeded[String((mod as StatModifier).stat)] = 10.0
	c.base_stats = seeded
	d.combat = c
	return d


## 把道具与邻居摆在一起编译，返回两者的属性表。摆不下就返回空。
static func _compile_pair(item: ItemDef, neighbor: ItemDef, at: Vector2i) -> Dictionary:
	if at.x < 0 or at.y < 0 or at.x >= BOARD.x or at.y >= BOARD.y:
		return {}
	var board := _board()
	var me := ItemInstance.create(item)
	if not board.place(me, CENTER, 0):
		return {}
	var other := ItemInstance.create(neighbor)
	if not board.place(other, at, 0):
		return {}

	var spec := BattleCompiler.compile(board, _generous_baseline(item))
	var mine := spec.stats_of(me.uid)
	var theirs := spec.stats_of(other.uid)
	if theirs == null:
		return {}
	return {"self": mine if mine != null else StatSet.new(), "neighbor": theirs}
#endregion
