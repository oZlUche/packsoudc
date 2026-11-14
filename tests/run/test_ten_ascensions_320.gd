## 320（十档进阶）：B 批 —— A1 普通敌人生命倍率、A3 猎手段内生命渐变、A4 更强的一种、按档写死的难度系数
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const Support := preload("res://tests/run/flow_support.gd")


static func _by_id(id: StringName) -> DifficultyDef:
	for d in GameFlow.load_difficulties():
		if (d as DifficultyDef).id == id:
			return d
	return null


static func run_hp_stamp(t: TestCase) -> void:
	t.begin("320 · 生命倍率：编译完乘一次，写的是最终值（重复写不叠），没有敌人不写")
	var c := {"enemy": "brute"}
	EnemyKit.stamp_hp(c, 1.1)
	EnemyKit.stamp_hp(c, 1.1)
	t.eq(float(c.get(EnemyKit.HP_MULT, 0.0)), 1.1, "写一次 1.1，再写还是 1.1")
	var empty := {}
	EnemyKit.stamp_hp(empty, 1.1)
	t.check(empty.is_empty(), "没有敌人不写")
	var one := {"enemy": "brute"}
	EnemyKit.stamp_hp(one, 1.0)
	t.check(not one.has(EnemyKit.HP_MULT), "倍率 1 不写")
	var spec := CombatantSpec.new()
	spec.max_hp = 200
	EnemyKit.scale_hp(spec, {EnemyKit.HP_MULT: 1.1})
	t.eq(spec.max_hp, 220, "200 × 1.1 = 220")


static func run_hunter_ramp(t: TestCase) -> void:
	t.begin("320 A3 · 猎手段内生命渐变：段首、段尾按表，中间线性，最后一段按步数走完")
	var m := HunterMechanic.new()
	m.bracket_steps = [0, 5, 10, 20] as Array[int]
	m.hp_from = [1.0, 0.6, 0.6, 0.5] as Array[float]
	m.hp_to = [1.4, 1.4, 1.6, 1.0] as Array[float]
	m.hp_last_span = 10
	t.check(absf(m.hp_for_steps(0) - (1.0)) <= 0.001, "第 0 步 ×1")
	t.check(absf(m.hp_for_steps(4) - (1.4)) <= 0.001, "第 4 步（段尾）×1.4")
	t.check(absf(m.hp_for_steps(5) - (0.6)) <= 0.001, "第 5 步换档，×0.6")
	t.check(absf(m.hp_for_steps(7) - (1.0)) <= 0.001, "第 7 步在中间，×1.0")
	t.check(absf(m.hp_for_steps(19) - (1.6)) <= 0.001, "第 19 步 ×1.6")
	t.check(absf(m.hp_for_steps(20) - (0.5)) <= 0.001, "第 20 步 ×0.5")
	t.check(absf(m.hp_for_steps(30) - (1.0)) <= 0.001, "第 30 步走完，×1.0")
	t.check(absf(m.hp_for_steps(80) - (1.0)) <= 0.001, "之后一直 ×1.0")
	var bare := HunterMechanic.new()
	t.check(absf(bare.hp_for_steps(12) - (1.0)) <= 0.001, "没写渐变 = 1")
	var three := _by_id(&"ascension_3")
	t.check(three != null and not three.mechanics.filter(func(x: RunMechanic) -> bool: return x is HunterMechanic and not (x as HunterMechanic).hp_from.is_empty()).is_empty(), "进阶三写了渐变")


static func run_ladder_b(t: TestCase) -> void:
	t.begin("320 B · 进阶一～四：去掉体力上限 −1，敌人生命倍率每档同一个最终值，进阶四开强敌，解锁接到四")
	var ids := [&"ascension_1", &"ascension_2", &"ascension_3", &"ascension_4"]
	var defs: Array[DifficultyDef] = []
	for id in ids:
		var d := _by_id(id)
		t.check(d != null, "%s 在" % id)
		if d == null:
			return
		defs.append(d)
	for d in defs:
		t.check(d.run_effects().is_empty(), "%s：不再扣体力上限" % d.id)
		t.check(absf(d.enemy_hp_mult() - (defs[0].enemy_hp_mult())) <= 0.0001, "%s：敌人生命倍率和进阶一一样（不连乘）" % d.id)
	t.check(defs[0].enemy_hp_mult() > 1.0, "进阶一的敌人更耐打")
	t.eq([defs[0].advanced_share(), defs[1].advanced_share(), defs[2].advanced_share()], [0.0, 0.0, 0.0], "一～三不换强敌")
	t.check(defs[3].advanced_share() > 0.0, "进阶四换强敌")
	t.eq(defs[3].level, 4, "进阶四是第 4 档")
	t.eq([defs[2].grants_unlock, defs[3].requires_unlock], [&"ascension_4", &"ascension_4"], "进阶三撤离开进阶四")
	t.eq(defs[3].hunter_bracket_steps(), defs[2].hunter_bracket_steps(), "进阶四的猎手和进阶三一样")
	var rules := ScoreRules.load_rules()
	t.eq([rules.mult(0), rules.mult(3), rules.mult(4)], [1.0, 1.75, 1.75], "计分系数：进阶四暂时和进阶三一样")


static func run_advanced_pool(t: TestCase) -> void:
	t.begin("320 A4 · 更强的一种：按配额换、开头几场不换、不相邻、本色更高、道具档位和节点类型不变")
	var c = NodeScreens._content()
	var four := _by_id(&"ascension_4")
	if four == null:
		t.check(false, "进阶四在")
		return
	var seen := 0
	for s in [3, 11, 29, 47]:
		var plain := RunState.start(c.chapter, s, c.items, c.enemies, c.sets)
		var run := RunState.start(c.chapter, s, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], four)
		if run == null or plain == null:
			t.check(false, "开局 %d" % s)
			continue
		var rep := run.advanced_report
		var replaced: Array = rep.get("replaced", [])
		t.check(replaced.size() <= int(rep.get("target", 0)), "种子 %d：不超过配额（%d / %d 场普通战斗，目标 %d）" % [s, replaced.size(), int(rep.get("battles", 0)), int(rep.get("target", 0))])
		t.eq(int(rep.get("target", 0)), roundi(four.advanced_share() * float(int(rep.get("battles", 0)))), "种子 %d：目标 = 份额 × 普通战斗数，四舍五入" % s)
		for id in replaced:
			var n := run.map.get_node(int(id))
			var was := plain.map.get_node(int(id))
			seen += 1
			t.eq(n.type, &"battle", "换上的还是普通战斗")
			t.check(bool(n.content.get(AdvancedPool.KEY, false)), "内容里记了一笔")
			t.eq(int(n.content.get("strength", -1)), int(was.content.get("strength", -2)), "道具档位不变")
			t.check(c.enemies.enemy(StringName(String(n.content["enemy"]))).strength > int(n.content["strength"]), "本色比想要的档高")
			for other in replaced:
				t.check(not run.map.neighbors(int(id)).has(int(other)), "换上的点不相邻")
		var near := {}
		for e in run.map.entry_ids:
			near[e] = 0
		var q: Array[int] = []
		q.assign(run.map.entry_ids)
		run.map.spread(near, q)
		var battles: Array[int] = []
		for id in run.map.node_ids():
			if run.map.get_node(id).type == &"battle" and EnemyKit.has_enemy(plain.map.get_node(id).content):
				battles.append(id)
		battles.sort_custom(func(a: int, b: int) -> bool: return int(near.get(a, 1 << 20)) < int(near.get(b, 1 << 20)) or (int(near.get(a, 1 << 20)) == int(near.get(b, 1 << 20)) and a < b))
		for id in battles.slice(0, four.advanced_skip_first):
			t.check(not replaced.has(id), "种子 %d：离入口最近的 %d 场不换（%d）" % [s, four.advanced_skip_first, id])
	t.check(seen > 0, "四个种子里至少换了一场（%d）" % seen)


static func run_enemy_hp_in_run(t: TestCase) -> void:
	t.begin("320 A1 · 一局里：图上的敌人和现造的都带倍率，猎手不吃；有档案的章不吃")
	var c = NodeScreens._content()
	var one := _by_id(&"ascension_1")
	if one == null:
		t.check(false, "进阶一在")
		return
	var run := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], one)
	var stamped := 0
	var foes := 0
	for id in run.map.node_ids():
		var content := run.map.get_node(id).content
		if EnemyKit.has_enemy(content):
			foes += 1
			if is_equal_approx(float(content.get(EnemyKit.HP_MULT, 1.0)), one.enemy_hp_mult()):
				stamped += 1
	t.check(foes > 0 and stamped == foes, "图上 %d 个敌人都写了倍率（%d）" % [foes, stamped])
	t.check(absf(run.events.enemy_hp_mult - (one.enemy_hp_mult())) <= 0.0001, "节点事件也拿到倍率（现造的敌人用）")
	var plain := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var any_id := -1
	for id in run.map.node_ids():
		if EnemyKit.has_enemy(run.map.get_node(id).content):
			any_id = id
			break
	if any_id >= 0:
		var a := EnemyKit.spec_of(run.map.get_node(any_id).content, c.enemies, run.pool, c.items)
		var b := EnemyKit.spec_of(plain.map.get_node(any_id).content, c.enemies, plain.pool, c.items)
		t.eq(a.max_hp, roundi(float(b.max_hp) * one.enemy_hp_mult()), "同一个敌人：生命 = 普通 × 倍率")
	var slice := c.chapter.duplicate() as ChapterDef
	slice.profile = &"test_profile"
	var sliced := RunState.start(slice, 5, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], one)
	t.check(absf(sliced.enemy_hp_mult() - (1.0)) <= 0.0001, "有档案的章不吃倍率")


static func run_faith_thresholds(t: TestCase) -> void:
	t.begin("320 A6 · 信仰门槛：首阶不变，之后 × 倍率四舍五入，严格递增；原表不动")
	t.eq(DifficultyDef.scale_thresholds([50, 150, 300, 1000] as Array[int], 10), [50, 165, 330, 1100] as Array[int], "日神 50 / 150 / 300 / 1000 → 50 / 165 / 330 / 1100")
	t.eq(DifficultyDef.scale_thresholds([3, 8] as Array[int], 10), [3, 9] as Array[int], "教会 3 / 8 → 3 / 9")
	t.eq(DifficultyDef.scale_thresholds([3, 4, 5] as Array[int], 10), [3, 4, 6] as Array[int], "小整数取整后至少比前一阶多 1")
	var d := DifficultyDef.new()
	d.faith_threshold_percent = 10
	var src := FaithDef.new()
	src.id = &"probe"
	src.thresholds = [10, 20] as Array[int]
	var out := d.scaled_faiths({&"probe": src})
	t.eq((out[&"probe"] as FaithDef).thresholds, [10, 22] as Array[int], "复制的那份改了")
	t.eq(src.thresholds, [10, 20] as Array[int], "原表没动")
	d.faith_threshold_percent = 0
	t.check(d.scaled_faiths({&"probe": src})[&"probe"] == src, "0 = 原样")


static func run_countdown_percent(t: TestCase) -> void:
	t.begin("320 A7 · 倒计时多扣：按累计行动点算、向下取整 —— 基础 1 点走 10 次扣 11，9 次扣 9")
	var c = NodeScreens._content()
	var d := DifficultyDef.new()
	d.countdown_percent = 10
	var run := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], d)
	var cd := CountdownModule.of(run)
	if cd == null or not cd.has_countdown():
		t.check(false, "这一章有倒计时")
		return
	run.travel.clock.total = 9
	t.eq(cd.spent(), 9, "9 个行动点扣 9")
	run.travel.clock.total = 10
	t.eq(cd.spent(), 11, "10 个行动点扣 11")
	t.eq(cd.left(), maxi(0, cd.limit() - 11), "剩余 = 上限 − 扣的")
	run.travel.clock.total = 25
	t.eq(cd.spent(), 27, "25 个扣 27（不逐步进位）")
	t.eq(run.hunters == null or run.hunters.step_count() == 25, true, "猎手看的步数不变")
	d.countdown_percent = 0
	t.eq(cd.spent(), 25, "0 = 照旧")


static func run_hunter_mods(t: TestCase) -> void:
	t.begin("320 A5 / A8 · 猎手生命乘在渐变上；直接攻击伤害终值 × 倍率，固定附伤不变")
	var spec := CombatantSpec.new()
	var it := CompiledItem.new()
	it.stats = StatSet.new()
	var v := it.stats.ensure(&"damage")
	v.base = StatMath.from_float(10.0)
	v.flat = StatMath.from_float(2.0)
	v.percent = StatMath.from_float(0.5)
	it.loaded = [{"damage": StatMath.from_float(4.0)}] as Array[Dictionary]
	spec.items = [it] as Array[CompiledItem]
	var before := StatMath.to_float(it.stats.total_of(&"damage"))
	EnemyKit.scale_damage(spec, {EnemyKit.DMG_MULT: 1.1})
	t.check(absf(StatMath.to_float(it.stats.total_of(&"damage")) - before * 1.1) <= 0.01, "伤害 %.2f → %.2f（× 1.1）" % [before, StatMath.to_float(it.stats.total_of(&"damage"))])
	t.check(absf(StatMath.to_float(int(it.loaded[0]["damage"])) - 4.4) <= 0.01, "晶石加的那份也 × 1.1")
	var content := {"enemy": "brute"}
	EnemyKit.stamp_damage(content, 1.0)
	t.check(not content.has(EnemyKit.DMG_MULT), "倍率 1 不写")
	var d := DifficultyDef.new()
	d.hunter_hp_percent = 10
	d.hunter_damage_percent = 5
	t.check(absf(d.hunter_hp_mult() - 1.1) <= 0.0001 and absf(d.hunter_damage_mult() - 1.05) <= 0.0001, "百分数换成倍率")


static func run_ladder_c(t: TestCase) -> void:
	t.begin("320 C · 进阶五～八：每一级只比上一级多一样，解锁接成一条链")
	var keys := ["hunter_hp_percent", "faith_threshold_percent", "countdown_percent", "hunter_damage_percent"]
	var prev := _by_id(&"ascension_4")
	for i in range(5, 9):
		var d := _by_id(StringName("ascension_%d" % i))
		t.check(d != null and prev != null, "进阶 %d 在" % i)
		if d == null or prev == null:
			return
		t.eq(d.level, i, "第 %d 档" % i)
		t.eq([prev.grants_unlock, d.requires_unlock], [d.id, d.id], "上一级撤离开 %s" % d.id)
		var changed: Array[String] = []
		for key in keys + ["enemy_hp_percent", "advanced_percent", "advanced_skip_first"]:
			if d.get(key) != prev.get(key):
				changed.append(key)
		t.eq(changed, [keys[i - 5]] as Array[String], "进阶 %d 只多了 %s" % [i, keys[i - 5]])
		t.eq(d.hunter_bracket_steps(), prev.hunter_bracket_steps(), "猎手段位表不变")
		t.check(not d.challenge.contains("；") and d.challenge.length() <= 10, "%s：中文一行（%s）" % [d.id, d.challenge])
		prev = d
	t.eq(prev.grants_unlock, &"ascension_9", "进阶八撤离开进阶九")
	var nine := _by_id(&"ascension_9")
	t.check(nine != null and nine.level == 9 and nine.requires_unlock == &"ascension_9" and nine.grants_unlock == &"", "进阶九：第 9 档，暂时是最后一级")
	t.eq(ScoreRules.load_rules().mult(8), 1.75, "计分系数：五～八暂时和进阶三一样")


static func run_flow_c(t: TestCase) -> void:
	t.begin("320 C · 一局里：进阶六的信仰表是改过门槛的那份（界面读的同一份），进阶五的猎手生命乘上 1.1")
	var c = NodeScreens._content()
	var kit: LoadoutDef = NodeScreens._kit(c)
	var f := Support.flow(c, "asc320c")
	f.difficulties = GameFlow.load_difficulties()
	var six := _by_id(&"ascension_6")
	f.meta.grant_unlock(six.requires_unlock)
	f.faith_defs = FaithDef.load_all()
	var run := f.begin(c.chapter, kit, 5, [] as Array[int], null, [], six)
	t.check(run != null, "进阶六开局")
	if run != null:
		var any := false
		for id in f.faith_defs:
			var base: FaithDef = f.faith_defs[id]
			var mine: FaithDef = run.faith_defs.get(id, null)
			t.check(mine != null and mine.thresholds == DifficultyDef.scale_thresholds(base.thresholds, six.faith_threshold_percent), "%s：门槛按档改过" % id)
			any = any or mine.thresholds != base.thresholds
		t.check(not f.faith_defs.is_empty() and any, "至少一种信仰的门槛变了（%d 种）" % f.faith_defs.size())
	Support.cleanup("asc320c")
	var five := _by_id(&"ascension_5")
	var f5 := Support.flow(c, "asc320c5")
	f5.difficulties = GameFlow.load_difficulties()
	f5.meta.grant_unlock(five.requires_unlock)
	var r5 := f5.begin(c.chapter, kit, 5, [] as Array[int], null, [], five)
	if r5 != null and r5.hunters != null:
		var ramp := r5.hunters.config.hp_for_steps(r5.hunters.step_count())
		t.check(absf(r5.hunters.hp_mult() - ramp * 1.1) <= 0.0001, "猎手生命 = 渐变 × 1.1（%.3f）" % r5.hunters.hp_mult())
	else:
		t.check(false, "进阶五开局、有猎手")
	Support.cleanup("asc320c5")


static func _plain_def(c) -> ItemDef:
	for id in c.items.ids():
		var d: ItemDef = c.items.get_def(id)
		var probe := ItemInstance.create(d, 0)
		if ItemErosion.eligible(probe) and d.combat != null:
			return d
	return null


static func _a9_run(c, s: int) -> RunState:
	var nine := _by_id(&"ascension_9")
	return RunState.start(c.chapter, s, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], nine) if nine != null else null


## 把侵蚀推到 [param node] 够深（直接改状态，测效果本身）
static func _deepen(run: RunState, node: MapNode, depth: int) -> void:
	run.travel.erosion.eroded_bands = node.erosion_band + depth


static func run_item_erosion_layers(t: TestCase) -> void:
	t.begin("320 A9 · 道具侵蚀：走进够深的点一件 +1，第 3 层永久损毁；待着不算；不够深不算；包、随身之物不算")
	var c = NodeScreens._content()
	var run := _a9_run(c, 7)
	if run == null or run.travel.erosion == null:
		t.check(false, "进阶九开局、有侵蚀")
		return
	var node := run.map.get_node(run.map.node_ids()[0])
	for inst in run.board.items():
		if not (inst as ItemInstance).def.is_bag:
			run.board.remove((inst as ItemInstance).uid)     # 包留着（格子在包上）
	for id in c.items.ids():     # 棋盘的格子在包上：先放一个包
		var bd: ItemDef = c.items.get_def(id)
		if bd.is_bag and run.board.try_add(ItemInstance.create(bd, 0), true):
			break
	var sword := ItemInstance.create(_plain_def(c), 0)
	t.check(run.board.try_add(sword, true), "棋盘上放一件")
	_deepen(run, node, 1)
	run.travel.erosion.settle(node, true)
	t.eq(ItemErosion.count(sword), 0, "深 1 层：不侵蚀道具")
	_deepen(run, node, 2)
	run.travel.erosion.settle(node, false)
	t.eq(ItemErosion.count(sword), 0, "待着（原地耗时）不算")
	run.travel.erosion.settle(node, true)
	t.eq(ItemErosion.count(sword), 1, "走进深 2 层：0 → 1")
	t.eq(ItemErosion.line(sword), UiText.t("erosion.item_line") % [1, 3], "浮窗：侵蚀1/3")
	run.travel.erosion.settle(node, true)
	t.eq(ItemErosion.count(sword), 2, "1 → 2，还在")
	t.check(run.board.has_item(sword.uid), "第 2 层还在棋盘上")
	var gone := [false]
	run.item_destroyed.connect(func(inst: ItemInstance, _why: StringName): gone[0] = inst == sword)
	run.travel.erosion.settle(node, true)
	t.check(not run.board.has_item(sword.uid) and gone[0], "第 3 层永久损毁（不是第 4 次）")
	var left := run.board.items().size()
	run.travel.erosion.settle(node, true)
	t.eq(run.board.items().size(), left, "只剩包（不合格）：什么也不做")
	t.check(not ItemErosion.eligible(null), "空的不算")
	for inst in run.board.items():
		t.check(ItemErosion.eligible(inst) or inst.def.is_bag or inst.is_pinned(), "合格规则")


static func run_item_erosion_lifecycle(t: TestCase) -> void:
	t.begin("320 A9 · 层数跟着实例走：存读档保留、合成继承最高值（满了合完损毁）、正常撤离清零、战败不清")
	var c = NodeScreens._content()
	var d := _plain_def(c)
	var a := ItemInstance.create(d, 0)
	ItemErosion.add(a)
	ItemErosion.add(a)
	var back := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())), c.items)
	t.eq([ItemErosion.count(back), ItemErosion.limit(back)], [2, 3], "存读档：2/3")
	var b := ItemInstance.create(d, 0)
	ItemErosion.add(b)
	var out := ItemInstance.create(d, 0)
	t.eq(ItemErosion.carry(out, [a, b]), 2, "合成继承最高的 2")
	var nine := _by_id(&"ascension_9")
	var fresh := RunState.start(c.chapter, 12, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], nine)
	t.check(fresh.resolve_difficulty(nine) == nine, "读档：快照和现在一样就用现在的那个对象")
	t.eq(ItemErosion.count(out), 2, "成品 2/3")
	t.check(not ItemErosion.is_full(out), "没满")
	ItemErosion.add(a)
	var full := ItemInstance.create(d, 0)
	ItemErosion.carry(full, [a])
	t.check(ItemErosion.is_full(full), "输入已满 → 成品满了（合完损毁）")
	var old := ItemInstance.from_dict({"uid": 999001, "def": String(d.id), "rot": 0, "origin": [0, 0], "seq": 0, "state": {}}, c.items)
	t.eq(ItemErosion.count(old), 0, "旧档没有字段 = 0")
	var run := _a9_run(c, 9)
	if run == null:
		return
	for id in c.items.ids():
		var bd: ItemDef = c.items.get_def(id)
		if bd.is_bag and run.board.try_add(ItemInstance.create(bd, 0), true):
			break
	var kept := ItemInstance.create(d, 0)
	t.check(run.board.try_add(kept, true), "棋盘上放一件")
	if run.board.has_item(kept.uid):
		ItemErosion.add(kept)
		run.phase = RunState.Phase.EXTRACTED
		var r := RunResult.settle(run)
		t.eq(ItemErosion.count(kept), 0, "正常撤离：带出来的清零")
		t.check(r.erosion_cleared >= 1, "回报记了清了几件")
	var lost := _a9_run(c, 10)
	var safe := SafeModule.of(lost) if lost != null else null
	if safe != null and safe.inventory != null:
		var keep := ItemInstance.create(d, 0)
		t.check(safe.inventory.try_add(keep, true), "托付一件")
		if safe.inventory.has_item(keep.uid):
			ItemErosion.add(keep)
			lost.phase = RunState.Phase.DEFEATED
			RunResult.settle(lost)
			t.eq(ItemErosion.count(keep), 1, "战败：托付出去的保留层数")


static func run_rule_snapshot(t: TestCase) -> void:
	t.begin("320 · 存档带着开局时的难度规则：读档按它重建，数据改了也不变")
	var c = NodeScreens._content()
	var nine := _by_id(&"ascension_9")
	var run := _a9_run(c, 11)
	if run == null:
		t.check(false, "进阶九开局")
		return
	t.check(run.difficulty_rules != "", "开局记了规则")
	var snap := run.difficulty_from_snapshot()
	t.check(snap != null and snap.id == nine.id and snap.level == 9, "按快照重建出来")
	t.eq([snap.enemy_hp_percent, snap.hunter_damage_percent, snap.countdown_percent], [nine.enemy_hp_percent, nine.hunter_damage_percent, nine.countdown_percent], "数一样")
	t.check(not snap.mechanics.filter(func(m: RunMechanic) -> bool: return m is ErosionMechanic and (m as ErosionMechanic).effects.any(func(e: ErosionEffect) -> bool: return e is ErodeItemLayer)).is_empty(), "道具侵蚀也在")
	var data: Dictionary = JSON.parse_string(run.difficulty_rules)
	data["enemy_hp_percent"] = 99
	run.difficulty_rules = JSON.stringify(data)
	t.eq(run.difficulty_from_snapshot().enemy_hp_percent, 99, "读的是快照，不是现在的数据")
	run.difficulty_rules = ""
	t.check(run.difficulty_from_snapshot() == null, "旧档没有快照：返回空（按 id 用现在的）")
	run.difficulty_rules = "{坏的"
	t.check(run.difficulty_from_snapshot() == null, "快照坏了：返回空")
