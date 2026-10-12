## 129（作者定）：负重 —— 每件道具一个重量，角色各有上限，科技加上限，超重三级递进（减急速 / 耐力回复 / 耐力上限 → 再减 → 走路翻倍）；不碰伤害
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["buffs"])


static func _character(id: String) -> CharacterDef:
	return load(ContentPaths.asset_file("characters", id)) as CharacterDef


## 角色定好、棋盘清空（只留包）的一局；[param cap] ≥ 0 时把上限改成它（复制一份角色，不动库里的）
static func _run(c: TestSupport.Content, cap: int = -1, meta: Array[StringName] = []) -> RunState:
	var ch := _character("andreus")
	if cap >= 0:
		ch = ch.duplicate()
		ch.weight_capacity = cap
	var kit: Array[StringName] = []
	for l in GameFlow.load_loadouts():
		if (l as LoadoutDef).id == &"standard":
			kit = (l as LoadoutDef).items.duplicate()
	var run := RunState.start(c.chapter, 7, c.items, c.enemies, c.sets, kit, c.buffs, meta, ch)
	return run


## 把这一局角色的上限改成 [param cap]（复制一份角色）
static func _set_cap(run: RunState, cap: int) -> void:
	var ch := run.character.duplicate() as CharacterDef
	ch.weight_capacity = cap
	run.set_character(ch)


static func _empty_board(run: RunState) -> void:
	run.board.begin_batch()
	for inst in run.board.items():
		var item := inst as ItemInstance
		if not run.board.acts_as_bag(item.def):
			run.board.remove(item.uid)
	run.board.end_batch()


static func run_weights(t: TestCase) -> void:
	t.begin("129/137 · 重量：写死的用写死的，其余按格数 × 材质类（重 4、金属 3、石与晶 2）；锚点")
	var c := _content()
	var anchors := {
		&"knife": 3, &"shortsword": 12, &"longsword": 15, &"plate_cuirass": 40, &"tower_shield": 48, &"round_shield": 12,     # 143：异形之后格数变了；塔盾 3×4 = 12 格、圆盾 2×2 = 4 格
		&"bag_leather": 0, &"bag_long": 0, &"bag_small": 0, &"ration": 1, &"iron_ore": 6, &"oak_log": 6, &"silk_bolt": 2,
		&"warhammer": 12, &"nail_keg": 12, &"high_tier_armor": 18, &"charm_brute": 1, &"bone_dice": 1, &"crowbar": 9,
		&"fire_crystal": 4,
	}
	for id in anchors:
		t.eq(ItemWeight.of(c.items.get_def(id)), int(anchors[id]), "%s 重 %d" % [id, anchors[id]])
	var d := ItemDef.new()
	d.shape = ItemShape.from_ascii(["11", "11"])
	t.eq(ItemWeight.of(d), 4, "没标签：每格 1")
	d.tags = [&"metal"] as Array[StringName]
	t.eq(ItemWeight.of(d), 12, "金属：每格 3")
	d.tags = [&"heavy", &"metal"] as Array[StringName]
	t.eq(ItemWeight.of(d), 16, "重：每格 4（先于金属）")
	d.tags = [&"gem"] as Array[StringName]
	t.eq(ItemWeight.of(d), 8, "晶体：每格 2")
	d.tags = [&"stone"] as Array[StringName]
	t.eq(ItemWeight.of(d), 8, "石材：每格 2")
	d.tags = [&"remedy"] as Array[StringName]
	t.eq(ItemWeight.of(d), 2, "轻：半格一重")
	d.weight = 9
	t.eq(ItemWeight.of(d), 9, "写死的覆盖公式")
	d.is_bag = true
	t.eq(ItemWeight.of(d), 0, "161：包不算重（写死的也不看）")
	var zero := 0
	for id in c.items.ids():
		var def := c.items.get_def(StringName(id))
		if not def.is_bag and ItemWeight.of(def) <= 0:
			zero += 1
	t.eq(zero, 0, "库里除了包没有零重的道具")


static func run_capacities(t: TestCase) -> void:
	t.begin("137 · 三人的负重上限：安德烈乌斯 40、马库斯 48、布鲁图斯 56")
	t.eq(_character("andreus").weight_capacity, 40, "安德烈乌斯 40")
	t.eq(_character("marcus").weight_capacity, 48, "马库斯 48")
	t.eq(_character("brutus").weight_capacity, 56, "布鲁图斯 56")
	var c := _content()
	var run := _run(c)
	t.not_null(run.encumbrance, "自由模式开着负重")
	t.eq(run.carry_capacity(), 40, "一局里的上限 = 角色的")
	t.check(run.carry_weight() > 0, "开局的包与装备有重量（%d）" % run.carry_weight())
	t.eq(run.encumbrance_level(), 0, "标准开局在安德烈乌斯身上是轻装")
	var rules: EncumbranceRules = load(ContentPaths.asset_file("encumbrance_rules", "standard"))
	for cap in [40, 48, 56]:
		t.eq(rules.level_of(35, cap), 0, "负重 35、上限 %d：轻装" % cap)
	t.eq(rules.level_of(48, 40), 0, "161：负重 48、安德烈乌斯（40）：1.2 倍还算轻装")
	t.eq(rules.level_of(60, 40), 1, "1.5 倍：吃力")
	t.eq(rules.level_of(76, 40), 2, "1.9 倍：超重")
	t.eq(rules.level_of(92, 40), 3, "2.3 倍：寸步难行（两倍之后才到顶）")
	for l in GameFlow.load_loadouts():
		var w := 0
		for id in (l as LoadoutDef).items:
			w += ItemWeight.of(c.items.get_def(id))
		t.check(w <= 40, "预设 %s 的开局负重 %d ≤ 最小上限 40" % [(l as LoadoutDef).id, w])
	var prologue: ChapterDef = load(ContentPaths.asset_file("chapters", "prologue"))
	t.eq(prologue.encumbrance_rules, &"", "序章不算负重")


static func run_levels(t: TestCase) -> void:
	t.begin("129 / 161 · 级数边界：上限 × 1.2 / × 1.6 / × 2.2 严格大于才升级")
	var rules: EncumbranceRules = load(ContentPaths.asset_file("encumbrance_rules", "standard"))
	t.not_null(rules, "标准负重规则在")
	var cases := [[40, 0], [48, 0], [49, 1], [64, 1], [65, 2], [88, 2], [89, 3], [200, 3], [0, 0]]
	for pair in cases:
		t.eq(rules.level_of(int(pair[0]), 40), int(pair[1]), "上限 40、负重 %d → %d 级" % [pair[0], pair[1]])
	t.eq(rules.level_of(500, 0), 0, "上限 0 = 不算负重")
	t.eq(rules.name_of(1), "吃力", "一级叫吃力")
	t.eq(rules.name_of(2), "超重", "二级叫超重")
	t.eq(rules.name_of(3), "寸步难行", "三级叫寸步难行")
	t.eq(rules.travel_mult_of(2), 1, "二级走路不翻倍")
	t.eq(rules.travel_mult_of(3), 2, "三级走路翻倍")
	for lv in [1, 2, 3]:
		for m in rules.row(lv).mods:
			t.check((m as StatModifier).stat != BattleStats.DAMAGE, "%d 级不碰伤害" % lv)


static func run_tech_bonus(t: TestCase) -> void:
	t.begin("129 · 科技「扛重」加上限，三条线一起往外推")
	var c := _content()
	t.check(c.buffs.has(&"tech_hauling_1") and c.buffs.has(&"tech_hauling_3"), "扛重的三级 buff 都在")
	var run := _run(c)
	var base_cap := run.carry_capacity()
	var with1 := _run(c, -1, [&"tech_hauling_1"] as Array[StringName])
	t.eq(with1.carry_capacity(), base_cap + 6, "扛重一级：上限 +6")
	var with3 := _run(c, -1, [&"tech_hauling_3"] as Array[StringName])
	t.eq(with3.carry_capacity(), base_cap + 20, "扛重三级：上限 +20")
	# 同样的负重，科技把级数压下来：上限改成刚好吃力
	var w := run.carry_weight()
	t.eq(with1.carry_weight(), w, "两边背的一样（%d）" % w)
	var cap := ceili(w / 1.2) - 1     # 刚好过一级门槛；+6 之后又在门槛下
	_set_cap(run, cap)
	_set_cap(with1, cap)
	t.eq(run.encumbrance_level(), 1, "没科技：吃力")
	t.eq(with1.encumbrance_level(), 0, "扛重一级：还是轻装")
	var tech: TechDef = load(ContentPaths.asset_file("techs", "hauling"))
	t.not_null(tech, "科技「扛重」在")
	if tech != null:
		t.eq(tech.requires, [&"endurance"] as Array[StringName], "前置是耐久")
		t.eq(tech.column, 1, "在身体那一列")


static func run_combat_mods(t: TestCase) -> void:
	t.begin("129 · 编译：急速、耐力回复、耐力上限按级减，伤害不变；buff 栏有一条「负重」")
	var c := _content()
	var light := _run(c, 500)
	var heavy := _run(c, 500)
	var a := light.compile_player()
	var cap := heavy.carry_weight()     # 上限 = 现在的负重：轻装
	var ch := heavy.character.duplicate() as CharacterDef
	ch.weight_capacity = maxi(1, int(floor(cap / 1.9)))     # 负重是上限的 1.9 倍左右：二级
	heavy.set_character(ch)
	t.eq(heavy.encumbrance_level(), 2, "二级（负重 %d / 上限 %d）" % [heavy.carry_weight(), heavy.carry_capacity()])
	var b := heavy.compile_player()
	var base := heavy.effective_baseline()
	var regen0 := StatMath.to_float(a.baseline.total_of(BattleStats.REGEN_STAMINA))
	var regen1 := StatMath.to_float(b.baseline.total_of(BattleStats.REGEN_STAMINA))
	var max0 := StatMath.to_float(a.baseline.total_of(BattleStats.MAX_STAMINA))
	var max1 := StatMath.to_float(b.baseline.total_of(BattleStats.MAX_STAMINA))
	t.check(absf(regen1 - (regen0 - 0.25 * base.value_of(BattleStats.REGEN_STAMINA))) < 0.01, "耐力回复少了基线的两成半（%.2f → %.2f）" % [regen0, regen1])
	t.check(absf(max1 - (max0 - 0.2 * base.value_of(BattleStats.MAX_STAMINA))) < 0.01, "耐力上限少了基线的两成（%.1f → %.1f）" % [max0, max1])
	var haste_ok := true
	var damage_same := true
	var compared := 0
	for it in a.items:
		var other := b.item_of((it as CompiledItem).source_uid)
		if other == null:
			continue
		compared += 1
		var h0 := StatMath.to_float(a.stats_of(it.source_uid).total_of(BattleStats.HASTE, StatMath.ONE))
		var h1 := StatMath.to_float(b.stats_of(it.source_uid).total_of(BattleStats.HASTE, StatMath.ONE))
		haste_ok = haste_ok and h1 < h0 - 0.001
		damage_same = damage_same and a.stats_of(it.source_uid).total_of(BattleStats.DAMAGE) == b.stats_of(it.source_uid).total_of(BattleStats.DAMAGE)
	t.check(compared > 0, "有参战道具可比（%d 件）" % compared)
	t.check(haste_ok, "每件参战道具的急速都降了")
	t.check(damage_same, "伤害一点没变")
	var noted := false
	for p in b.passives:
		if (p as PassiveNote).id == &"encumbrance":
			noted = true
	t.check(noted, "buff 栏有「负重」那一条")
	var none := true
	for p in a.passives:
		if (p as PassiveNote).id == &"encumbrance":
			none = false
	t.check(none, "轻装时没有")


static func run_travel_doubles(t: TestCase) -> void:
	t.begin("129 · 寸步难行：走一步扣双倍行动点（预览读同一个数），原地等待不翻倍；减下来就恢复")
	var c := _content()
	var run := _run(c)
	var levels: Array = []
	run.encumbrance_changed.connect(func(lv: int): levels.append(lv))
	run.pick_spawn(run.map.entry_ids[0])
	var ch := run.character.duplicate() as CharacterDef
	ch.weight_capacity = maxi(1, int(floor(run.carry_weight() / 2.5)))     # 负重是上限的 2.5 倍：三级
	run.set_character(ch)
	t.eq(run.encumbrance_level(), 3, "三级")
	t.eq(levels, [3], "级数变了发一次信号")
	t.eq(run.travel.action_cost_mult, 2, "走路倍数写进了旅程")
	var to: int = run.travel.available_moves()[0]
	var intent := MapNavigator.resolve_step(run.map, run.travel.current_id, to)
	t.eq(run.travel.cost_of(intent), intent.action_cost * 2, "预览：花双倍")
	var before := run.travel.clock.total
	t.check(run.travel.step_to(to), "走一步")
	t.eq(run.travel.clock.total - before, intent.action_cost * 2, "真扣了双倍")
	before = run.travel.clock.total
	run.travel.wait(1)
	t.eq(run.travel.clock.total - before, 1, "原地等待不翻倍")
	_empty_board(run)
	t.check(run.encumbrance_level() < 3, "卸到只剩包：不再寸步难行（%d 级）" % run.encumbrance_level())
	t.eq(run.travel.action_cost_mult, 1, "棋盘一变就重算：走路恢复")
	t.eq(levels.back(), run.encumbrance_level(), "发了级数变了的信号")


static func run_ground_and_safe_free(t: TestCase) -> void:
	t.begin("129 · 地上、保险箱不算重；只算作战棋盘（161：包不算）")
	var c := _content()
	var run := _run(c)
	var w := run.carry_weight()
	var plate := ItemInstance.create(c.items.get_def(&"plate_cuirass"))
	run.storage.admit(plate)
	t.eq(run.carry_weight(), w, "板甲放在地上：负重不变")
	var safe := SafeModule.of(run)
	if safe != null and safe.inventory != null:
		safe.inventory.try_add(ItemInstance.create(c.items.get_def(&"oak_log")), true)
		t.eq(run.carry_weight(), w, "保险箱里的不算")
	var bags := 0
	for inst in run.board.items():
		if run.board.acts_as_bag((inst as ItemInstance).def):
			bags += ItemWeight.of((inst as ItemInstance).def)
	t.eq(bags, 0, "161：包本身不算重")
	_empty_board(run)
	t.eq(run.carry_weight(), 0, "棋盘上只剩包：负重 0")


static func run_save_round_trip(t: TestCase) -> void:
	t.begin("129 · 存档不加字段：读回来按角色与棋盘重算，级数一致")
	var c := _content()
	var run := _run(c)
	_set_cap(run, int(floor(run.carry_weight() / 1.3)))
	t.eq(run.encumbrance_level(), 1, "存之前：吃力")
	var back := RunState.from_dict(run.to_dict(), c.chapter, c.items, c.enemies, c.sets)
	t.not_null(back, "读回来")
	back.set_character(run.character)
	t.eq(back.carry_weight(), run.carry_weight(), "负重一致")
	t.eq(back.encumbrance_level(), 1, "级数一致")
	t.check(not JSON.stringify(run.to_dict()).contains("encumbrance"), "存档里没有负重字段")
