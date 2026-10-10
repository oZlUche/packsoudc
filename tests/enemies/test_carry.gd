## 126（作者定）：敌人身上随机带非战斗道具 —— 0～N 件、越值钱越少见；出现（CarryRule）与掉落（DropRule）各掷各的，携带品必掉
extends RefCounted


static func _content() -> TestSupport.Content:
	return TestSupport.load_content("free_mode", ["carry"])


static func _carried(content: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for raw in content.get("items", []):
		if bool((raw as Dictionary).get("carried", false)):
			out.append(StringName(String((raw as Dictionary).get("id", ""))))
	return out


static func _build(c: TestSupport.Content, enemy: StringName, strength: int, seed: int, carry: CarryRule) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return EnemyPlacer.build_content(c.enemies.enemy(enemy), c.pool, c.items, strength, rng, carry)


static func run(t: TestCase) -> void:
	var c := _content()
	t.begin("126 · 自由模式引用标准携带规则；序章不带")
	t.not_null(c.carry, "free_mode → carry_rules/standard")
	for ch in ["prologue", "prologue_2"]:
		var p: ChapterDef = load(ContentPaths.asset_file("chapters", ch))
		t.eq(p.carry_rule, &"", "%s 不带" % ch)
	if c.carry == null or c.pool == null:
		return

	t.begin("126 · 候选只有无战斗档的材料（不是包、不是珍宝）")
	var cands := c.carry.candidates(c.items, -1)
	t.check(cands.size() >= 20, "候选 %d 件" % cands.size())
	for id in cands:
		var d := c.items.get_def(id)
		t.check(d.combat == null and not d.is_bag and d.tags.has(&"material") and not d.tags.has(&"treasure"), "%s：无战斗档的材料" % id)
	t.check(not cands.has(&"magic_staff"), "魔法杖是武器，不在里面")

	t.begin("126 · 同一种子两次一样；不带规则时敌人和战斗道具不变（携带用另一条随机数）")
	var enemy := c.pool.entries[0].enemy
	for strength in 4:
		var a := _build(c, enemy, strength, 11 + strength, c.carry)
		var b := _build(c, enemy, strength, 11 + strength, c.carry)
		t.eq(a, b, "档位 %d：两次一样" % strength)
		var plain := _build(c, enemy, strength, 11 + strength, null)
		var no_carry: Array = []
		for raw in (a["content"] as Dictionary)["items"]:
			if not bool((raw as Dictionary).get("carried", false)):
				no_carry.append(raw)
		t.eq(no_carry, (plain["content"] as Dictionary)["items"], "档位 %d：战斗道具与不带时一样" % strength)

	t.begin("126 · 件数落在区间（放不下的计入差件）；档位越高带得越多")
	var totals: Array[int] = [0, 0, 0, 0]
	for strength in 4:
		var span := c.carry.count_range(strength)
		for seed in 60:
			var built := _build(c, enemy, strength, 1000 + seed, c.carry)
			var n := _carried(built["content"]).size()
			t.check(n <= span.y, "档位 %d 种子 %d：%d 件 ≤ %d" % [strength, seed, n, span.y])
			totals[strength] += n
	t.check(totals[3] > totals[0], "档位 3 合计 %d 件 > 档位 0 的 %d 件" % [totals[3], totals[0]])

	t.begin("126 · 越值钱越少见：大样本里便宜货出现得多")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	var big := CarryRule.new()
	big.count_by_strength = [Vector2i(1, 1)]
	big.rarity_cap_bonus = 99
	for i in 3000:
		for id in big.roll(c.items, 0, -1, rng):
			seen[id] = int(seen.get(id, 0)) + 1
	var cheap := 0
	var dear := 0
	for id in seen:
		var v := ItemValue.of(c.items.get_def(id))
		if v <= 20:
			cheap += int(seen[id])
		elif v >= 200:
			dear += int(seen[id])
	t.check(cheap > dear * 5, "便宜（≤20）%d 次，贵（≥200）%d 次" % [cheap, dear])
	t.check(big.weight(c.items.get_def(&"copper_ore")) > big.weight(c.items.get_def(&"silk_bolt")), "铜矿石权重大于丝绸卷")

	t.begin("126 · 带不下的跳过，回报里单记（carry_short）")
	var greedy := CarryRule.new()
	greedy.count_by_strength = [Vector2i(60, 60)]
	var built := _build(c, enemy, 0, 3, greedy)
	var on := _carried(built["content"]).size()
	t.eq(int(built["carry_short"]), 60 - on, "摆上 %d 件，跳过 %d 件" % [on, int(built["carry_short"])])
	t.eq(int(built["dropped"]), int(_build(c, enemy, 0, 3, null)["dropped"]), "战斗道具的差件不受影响")

	t.begin("126 · 掉落：携带品必掉、不占保底名额；关掉 carried_always_drop 就和别的一样掷")
	var content: Dictionary = {}
	for seed in 200:
		var b := _build(c, enemy, 3, 400 + seed, c.carry)
		if not _carried(b["content"]).is_empty():
			content = b["content"]
			break
	t.check(not content.is_empty(), "找到一个带东西的敌人")
	var rule: DropRule = load(ContentPaths.asset_file("drop_rules", "standard"))
	var carried := _carried(content)
	for k in 20:
		var r := RandomNumberGenerator.new()
		r.seed = k
		var rolled := DropResolver.roll(content, rule, LootContext.new(), c.items, r)
		var dropped: Array[StringName] = rolled["dropped"]
		var all_in := true
		for id in carried:
			if not dropped.has(id):
				all_in = false
		t.check(all_in, "种子 %d：携带品全掉" % k)
		t.check(dropped.size() >= carried.size() + mini(rule.min_drops, content["items"].size() - carried.size()), "种子 %d：保底另算" % k)
		var corpse := DropResolver.corpse_of(content, rolled, c.items)
		var in_corpse := 0
		for inst in corpse.items():
			if carried.has((inst as ItemInstance).def.id):
				in_corpse += 1
		t.check(in_corpse >= carried.size(), "种子 %d：尸体容器里有全部携带品" % k)
	t.check(EnemyKit.summary(content, c.enemies, c.pool, c.items).contains("携带 %d 件" % carried.size()), "摘要写了携带几件")
	var plain_rule: DropRule = rule.duplicate()
	plain_rule.carried_always_drop = false
	var missed := false
	for k in 40:
		var r := RandomNumberGenerator.new()
		r.seed = k
		var dropped: Array[StringName] = DropResolver.roll(content, plain_rule, LootContext.new(), c.items, r)["dropped"]
		for id in carried:
			if not dropped.has(id):
				missed = true
	t.check(missed, "不必掉时有掷不中的")

	t.begin("126 · 导入器：件数区间与 value_power 校验")
	var ctx := ContentImporter.Context.new()
	for pair in [[{"id": "x"}, true], [{"id": "x", "count_by_strength": [[2, 1]]}, false], [{"id": "x", "value_power": 0}, false], [{"id": "x", "count_by_strength": [[-1, 1]]}, false]]:
		var report := ImportReport.new()
		ContentImporter.import_carry_rule(pair[0], ctx, report)
		t.eq(report.ok(), pair[1], "%s：%s" % [pair[0], "通过" if pair[1] else "拦下"])
