## 360 第一批（作者难度表 D、E、G、H 列）：搜索逐件下限、普通敌人持有物最低掉落占比（两轮算法）、精英额外掉落随难度
extends RefCounted

## 作者难度表 G 列（A0 由掉落规则给）
const HELD := {0: 20, 1: 25, 2: 30, 3: 35, 4: 40, 5: 50, 6: 60, 7: 70, 8: 80, 9: 80, 10: 80, 11: 80}
## H 列：精英额外一件的稀有度
const ELITE := {0: 1, 1: 1, 2: 1, 3: 1, 4: 2, 5: 2, 6: 2, 7: 2, 8: 3, 9: 3, 10: 3, 11: 3}
## D、E 列：常规 / 进阶搜索逐件下限
const FLOORS := {
	0: [[0, 0], [1, 0]], 1: [[1, 0], [1, 1, 0]], 2: [[1, 1, 0], [2, 1, 1]], 3: [[2, 1, 1], [2, 2, 1]],
	4: [[2, 1, 1], [3, 2, 1]], 5: [[2, 2, 1], [3, 2, 1]], 6: [[2, 2, 1], [3, 2, 1]], 7: [[3, 2, 1], [3, 2, 1]],
	8: [[3, 2, 1], [3, 3, 1]], 9: [[3, 3, 1], [3, 3, 2]], 10: [[3, 3, 1], [3, 3, 2]], 11: [[3, 3, 3], [4, 3, 2]],
}
const SIX := ["knife", "ration", "bandage", "salve", "whetstone", "iron_ore"]


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode")


static func _ids(raw: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in raw:
		out.append(StringName(id))
	return out


static func _enemy(ids: Array) -> Dictionary:
	var items: Array = []
	for id in ids:
		items.append({"id": id})
	return {"items": items}


## 第一轮一件都不掉的规则：只看第二轮
static func _silent_rule() -> DropRule:
	var r := DropRule.new()
	r.base_chance = [0.0] as Array[float]
	r.difficulty_bonus = 0.0
	r.luck_bonus = 0.0
	r.min_drops = 0
	r.elite_rarity = -1
	return r


static func _by_level() -> Dictionary:
	var out := {}
	for d in GameFlow.load_difficulties():
		out[(d as DifficultyDef).level] = d
	return out


static func run_top_up(t: TestCase) -> void:
	t.begin("360 · 第二轮补足：N = max(0, ceil(M × r) − K)，只从没掉的里抽，M 为 0 直接结束")
	var c := _content()
	for id in SIX:
		t.not_null(c.items.get_def(StringName(id)), "有 %s" % id)
	var rule := _silent_rule()
	var rng := RandomNumberGenerator.new()
	rng.seed = 360
	var dropped := _ids(["knife", "ration", "bandage"])
	t.eq(DropResolver.top_up(_ids(SIX), dropped, 0.8, rule, c.items, rng), 2, "持有 6 件、下限 80%、第一轮掉 3 件：补 2 件")
	t.eq(dropped.size(), 5, "一共 5 件")
	var seen := {}
	for id in dropped:
		t.check(not seen.has(id), "%s 没重复" % id)
		seen[id] = true
	var full := _ids(SIX)
	t.eq(DropResolver.top_up(_ids(SIX), full, 0.8, rule, c.items, rng), 0, "第一轮掉了 6 件：全保留，不补")
	t.eq(DropResolver.top_up(_ids([]), _ids([]), 0.8, rule, c.items, rng), 0, "M 为 0：直接结束")
	var one := _ids([])
	t.eq(DropResolver.top_up(_ids(["knife"]), one, 0.2, rule, c.items, rng), 1, "只有 1 件、下限 20%：这件必掉")
	var twin := _ids(["knife"])
	t.eq(DropResolver.top_up(_ids(["knife", "knife"]), twin, 1.0, rule, c.items, rng), 1, "同 id 两件、掉了一件：按件数再补一件")
	t.eq(twin.size(), 2, "两把小刀都掉了")
	var none := _ids([])
	t.eq(DropResolver.top_up(_ids(SIX), none, 0.0, rule, c.items, rng), 0, "下限 0：不补")
	var five := _ids([])
	DropResolver.top_up(_ids(SIX.slice(0, 5)), five, 0.2, rule, c.items, rng)
	t.eq(five.size(), 1, "5 件 × 20% = 1：正好 1 件，不多补")


static func run_floor_holds(t: TestCase) -> void:
	t.begin("360 · 两轮掉落：各档下限、各持有件数（1～6）下整场件数都够；只管普通敌人")
	var c := _content()
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	t.eq(rule.held_floor_percent, 20, "标准掉落规则：A0 下限 20%")
	t.eq(rule.elite_rarity, 1, "标准掉落规则：A0 精英额外一件优良")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for lv in HELD:
		var share := float(HELD[lv]) / 100.0
		for m in range(1, 7):
			var ctx := LootContext.new()
			ctx.held_floor = share
			var content := _enemy(SIX.slice(0, m))
			var ok := true
			for i in 20:
				var r := DropResolver.roll(content, rule, ctx, c.items, rng, false, false, true)
				if (r["dropped"] as Array).size() < ceili(float(m) * share - 0.000001):
					ok = false
			t.check(ok, "A%d、持有 %d 件：每场至少 %d 件" % [lv, m, ceili(float(m) * share - 0.000001)])
	var silent := _silent_rule()
	var hard := LootContext.new()
	hard.held_floor = 1.0
	var content6 := _enemy(SIX)
	t.eq((DropResolver.roll(content6, silent, hard, c.items, rng, false, true, false)["dropped"] as Array).size(), 0, "精英：不补")
	t.eq((DropResolver.roll(content6, silent, hard, c.items, rng, true, false, false)["dropped"] as Array).size(), 0, "首领：不补")
	t.eq((DropResolver.roll(content6, silent, hard, c.items, rng, false, false, true)["dropped"] as Array).size(), 6, "普通敌人、下限 100%：全掉")
	t.check(NodeEvents.is_regular(&"battle") and NodeEvents.is_regular(&"search"), "普通战、搜索遭遇算普通敌人")
	t.check(not NodeEvents.is_regular(&"elite") and not NodeEvents.is_regular(&"core") and not NodeEvents.is_regular(&"hunter"), "精英、首领、猎手不算")


static func run_elite_extra(t: TestCase) -> void:
	t.begin("360 · 精英额外掉落：难度写了按难度的稀有度，没写沿用掉落规则")
	var c := _content()
	var rule := _silent_rule()
	rule.elite_rarity = 1
	var ctx := LootContext.new()
	t.eq(DropResolver.elite_rarity_of(rule, ctx), 1, "难度没写：用规则的")
	t.eq(DropResolver.elite_rarity_of(rule, null), 1, "没有上下文：用规则的")
	var def := DifficultyDef.new()
	def.elite_rarity = 3
	def.held_floor_percent = 70
	ctx.apply_difficulty(def)
	t.eq(DropResolver.elite_rarity_of(rule, ctx), 3, "难度写 3：史诗")
	t.eq(DropResolver.held_floor_of(rule, ctx), 0.7, "难度写 70：0.7")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var r := DropResolver.roll(_enemy(["knife"]), rule, ctx, c.items, rng, false, true, false)
	var treasure: Array = r["treasure"]
	t.eq(treasure.size(), 1, "精英多一件")
	if treasure.size() == 1:
		t.eq(c.items.get_def(treasure[0]).rarity, 3, "那一件是史诗（%s）" % treasure[0])
	var plain := DropResolver.roll(_enemy(["knife"]), rule, ctx, c.items, rng, false, false, true)
	t.eq((plain["treasure"] as Array).size(), 0, "普通战：没有这一件")


static func run_difficulty_data(t: TestCase) -> void:
	t.begin("360 · 各档数据对得上作者难度表（搜索下限、持有物下限、精英额外稀有度）")
	var defs := _by_level()
	var nr: NodeRules = load(ContentPaths.asset_file("node_rules", "standard"))
	var search_rules: SearchRules = nr.search if nr != null else null
	t.not_null(search_rules, "标准搜索规则在")
	var normal_node := MapNode.new()
	normal_node.content = {"search_tier": "normal"}
	var adv_node := MapNode.new()
	adv_node.content = {"search_tier": "advanced"}
	for lv in FLOORS:
		var def: DifficultyDef = defs.get(lv, null)
		if lv > 0:
			t.not_null(def, "A%d 在" % lv)
			if def == null:
				continue
			t.eq(def.held_floor_percent, HELD[lv], "A%d 持有物下限" % lv)
			t.eq(def.elite_rarity, ELITE[lv], "A%d 精英额外稀有度" % lv)
		var want_n: Array[int] = []
		want_n.assign(FLOORS[lv][0])
		var want_a: Array[int] = []
		want_a.assign(FLOORS[lv][1])
		t.eq(SearchSession.floor_for(normal_node, search_rules, def), want_n, "A%d 常规搜索" % lv)
		t.eq(SearchSession.floor_for(adv_node, search_rules, def), want_a, "A%d 进阶搜索" % lv)
