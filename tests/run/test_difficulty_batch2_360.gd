## 360 第二批（作者难度表 A1 到 A10 的机制换档；武器那一列照报告 367 的作者裁定）
extends RefCounted

const NodeScreens := preload("res://tests/ui/test_node_screens.gd")

## 拿掉的六条旧机制（代码开关留着，数据里不再有）
const RETIRED := ["enemy_hp_percent", "advanced_percent", "hunter_hp_percent", "hunter_damage_percent", "faith_threshold_percent", "hunter_chase_percent"]


static func _by_level() -> Dictionary:
	var out := {}
	for d in GameFlow.load_difficulties():
		out[(d as DifficultyDef).level] = d
	return out


static func _want(lv: int) -> Dictionary:
	return {
		"gear_cap_battle": 0 if lv < 1 else (1 if lv < 4 else 2),
		"gear_cap_elite": 1 if lv >= 4 else 0,
		"elite_extra_items": 1 if lv >= 4 else 0,
		"allow_true_damage": lv >= 4,
		"rest_keep_percent": 50 if lv >= 5 else 100,
		"no_paid_extract": lv >= 5,
		"boss_hp_percent": 25 if lv >= 6 else 0,
		"boss_speed_percent": 20 if lv >= 6 else 0,
		"countdown_percent": 10 if lv >= 7 else 0,
		"hunter_loss_extra": 1 if lv >= 8 else 0,
		"enemy_weapon_quality": 1 if lv >= 8 else 0,
	}


static func run_data(t: TestCase) -> void:
	t.begin("360 第二批 · 各档数据：新机制按档累计，六条旧机制从数据里拿掉，A10 两个首领有强化版")
	var defs := _by_level()
	for lv in range(1, 11):
		var d: DifficultyDef = defs.get(lv, null)
		t.not_null(d, "A%d 在" % lv)
		if d == null:
			continue
		var want := _want(lv)
		for key in want:
			t.eq(d.get(key), want[key], "A%d %s" % [lv, key])
		for key in RETIRED:
			t.eq(int(d.get(key)), 0, "A%d 不再有 %s" % [lv, key])
		t.check(not d.description.is_empty() and not d.challenge.is_empty(), "A%d 有说明和挑战" % lv)
		t.eq(d.boss_upgrades.has("core_guardian"), lv >= 10, "A%d 核心守卫强化版" % lv)
	var ten: DifficultyDef = defs.get(10, null)
	if ten != null:
		t.eq(String(ten.boss_upgrades["core_guardian"]["title"]), "誓约守卫", "A10：誓约守卫")
		t.eq(String(ten.boss_upgrades["great_clock"]["title"]), "永动大钟", "A10：永动大钟")


static func run_boosted_tier(t: TestCase) -> void:
	t.begin("360 第二批 · 配装加成：上限抬档（不限仍不限、封顶史诗）、精英多一件、放开真实伤害")
	var tier := StrengthTier.new()
	tier.rarity_cap = 1
	tier.weapon_rarity_cap = 0
	tier.item_count = Vector2i(2, 3)
	tier.weapon_no_true_damage = true
	t.check(EnemyPlacer.boosted_tier(tier, {}) == tier, "没有加成：原样（不复制）")
	var one := EnemyPlacer.boosted_tier(tier, {"cap": 1})
	t.eq(one.rarity_cap, 2, "道具上限 1 → 2")
	t.eq(one.weapon_rarity_cap, 1, "武器上限 0 → 1")
	t.eq(tier.rarity_cap, 1, "原档位不动")
	var two := EnemyPlacer.boosted_tier(tier, {"cap": 2, "items": 1, "true_ok": true})
	t.eq(two.weapon_rarity_cap, 2, "武器上限 0 → 2（367 第二节 A4 普通战 0 档：稀有）")
	t.eq(two.item_count, Vector2i(3, 4), "多带一件")
	t.check(not two.weapon_no_true_damage, "放开真实伤害")
	var deep := StrengthTier.new()
	deep.weapon_rarity_cap = 3
	var d2 := EnemyPlacer.boosted_tier(deep, {"cap": 2})
	t.eq(d2.weapon_rarity_cap, 3, "史诗再抬还是史诗（不拿传说）")
	t.eq(d2.rarity_cap, -1, "不限的仍不限")
	var mid := StrengthTier.new()
	mid.weapon_rarity_cap = 2
	t.eq(EnemyPlacer.boosted_tier(mid, {"cap": 2}).weapon_rarity_cap, 3, "稀有抬两档封顶史诗")
	var a4 := DifficultyDef.new()
	a4.gear_cap_battle = 2
	a4.gear_cap_elite = 1
	a4.elite_extra_items = 1
	t.eq(a4.gear_boost(&"battle"), {"cap": 2}, "普通战 +2")
	t.eq(a4.gear_boost(&"search"), {"cap": 2}, "搜索遭遇算普通战")
	t.eq(a4.gear_boost(&"elite"), {"cap": 1, "items": 1}, "精英 +1、多一件")
	t.eq(a4.gear_boost(&"core"), {}, "首领不变")
	a4.enemy_weapon_quality = 1
	t.eq(a4.gear_boost(&"core"), {"quality": 1}, "A8 起首领武器也带品质")


static func run_weapon_quality(t: TestCase) -> void:
	t.begin("360 第二批 A8 · 敌人武器品质：记进内容，编译与掉落都恢复")
	var c = NodeScreens._content()
	var placed: Array = [{"id": "knife"}, {"id": "ration"}]
	EnemyPlacer.stamp_weapon_quality(placed, c.items, 1)
	t.eq(int(placed[0].get(ItemInstance.QUALITY_KEY, 0)), 1, "小刀（武器）带品质 1")
	t.check(not (placed[1] as Dictionary).has(ItemInstance.QUALITY_KEY), "口粮不是武器：不写")
	var board := EnemyKit.board_of({"board": [4, 3], "items": placed}, c.items)
	var q := -1
	for inst in board.items():
		if (inst as ItemInstance).def.id == &"knife":
			q = (inst as ItemInstance).quality()
	t.eq(q, 1, "棋盘上那把小刀品质 1")
	var corpse := DropResolver.corpse_of({"board": [4, 3], "items": placed}, {"dropped": [&"knife"] as Array[StringName]}, c.items)
	var dq := -1
	for inst in corpse.items():
		if (inst as ItemInstance).def.id == &"knife":
			dq = (inst as ItemInstance).quality()
	t.eq(dq, 1, "掉下来的小刀也是品质 1")


static func run_map_trims(t: TestCase) -> void:
	t.begin("360 第二批 A5 · 休息点减半（向下取整、至少一个）、撤离点只留会关闭的那个")
	var g := MapGraph.new()
	var types := [&"rest", &"rest", &"rest", &"rest", &"rest", &"extract", &"extract", &"extract"]
	for i in types.size():
		var n := MapNode.new()
		n.id = i
		n.type = types[i]
		g.add_node(n)
	g.get_node(6).content["closes_at"] = 20
	g.get_node(7).content["fee"] = 30
	t.eq(DifficultyMap.trim_rests(g, 50, 7), 3, "五个休息点留两个")
	var rests := 0
	for id in g.node_ids():
		if g.get_node(id).type == &"rest":
			rests += 1
	t.eq(rests, 2, "剩两个")
	t.eq(DifficultyMap.trim_rests(g, 100, 7), 0, "100%：不动")
	t.eq(DifficultyMap.keep_one_extract(g), 6, "留下会关闭的那个")
	var ex := 0
	for id in g.node_ids():
		if g.get_node(id).type == &"extract":
			ex += 1
	t.eq(ex, 1, "只剩一个撤离点")
	t.eq(g.get_node(7).type, &"junction", "付费的变成路口")
	var lone := MapGraph.new()
	var r := MapNode.new()
	r.id = 0
	r.type = &"rest"
	lone.add_node(r)
	t.eq(DifficultyMap.trim_rests(lone, 50, 7), 0, "只有一个休息点：留着")


static func run_in_run(t: TestCase) -> void:
	t.begin("360 第二批 · 一局里：A5 撤离点一个、休息点变少；A6 首领生命 ×1.25、加速；A10 首领换名")
	var c = NodeScreens._content()
	var defs := _by_level()
	var plain := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets)
	var five: DifficultyDef = defs.get(5, null)
	var ten: DifficultyDef = defs.get(10, null)
	if five == null or ten == null:
		t.check(false, "A5、A10 在")
		return
	var r5 := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], five)
	var count := func(run: RunState, type: StringName) -> int:
		var n := 0
		for id in run.map.node_ids():
			if run.map.get_node(id).type == type:
				n += 1
		return n
	var bilateral := bool(r5.map.layout_meta.get("two_sided", false))
	if not bilateral:
		t.eq(count.call(r5, &"extract"), 1, "A5：只剩一个撤离点")
		var fees := 0
		for id in r5.map.node_ids():
			fees += PaidExtracts.fee_of(r5.map.get_node(id))
		t.eq(fees, 0, "A5：没有付费撤离点")
	var pr: int = count.call(plain, &"rest")
	if pr > 1:
		@warning_ignore("integer_division")
		t.eq(count.call(r5, &"rest"), maxi(1, pr / 2), "A5：休息点 %d → 一半" % pr)
	var r10 := RunState.start(c.chapter, 5, c.items, c.enemies, c.sets, [] as Array[StringName], {}, [] as Array[StringName], null, [], ten)
	for id in r10.map.node_ids():
		var n := r10.map.get_node(id)
		if n.type != &"core" or not EnemyKit.has_enemy(n.content):
			continue
		t.eq(float(n.content.get(EnemyKit.HP_MULT, 1.0)), 1.25, "A10（含 A6）：首领生命 ×1.25")
		t.check(float(n.content.get(EnemyKit.SPEED_MULT, 1.0)) > 1.2, "首领加速")
		var eid := String(n.content.get("enemy", ""))
		if ten.boss_upgrades.has(eid):
			t.eq(EnemyKit.title_of(n.content, c.enemies.enemy(StringName(eid))), String(ten.boss_upgrades[eid]["title"]), "首领换名：%s" % eid)
		var fast := EnemyKit.spec_of(n.content, c.enemies, r10.pool, c.items)
		var slow_content: Dictionary = n.content.duplicate(true)
		slow_content.erase(EnemyKit.SPEED_MULT)
		var slow := EnemyKit.spec_of(slow_content, c.enemies, r10.pool, c.items)
		if fast != null and slow != null and not fast.items.is_empty():
			var hf := fast.items[0].stats.ensure(BattleStats.HASTE).base
			var hs := slow.items[0].stats.ensure(BattleStats.HASTE).base
			t.check(hf > hs, "首领第一件的触发速度更快（%d > %d）" % [hf, hs])
	for id in plain.map.node_ids():
		var n := plain.map.get_node(id)
		if n.type == &"core":
			t.check(not n.content.has(EnemyKit.SPEED_MULT) and not n.content.has("title"), "普通难度：首领不动")
