## 247：法杖敌人四阶（魔法学徒 / 熟练的魔法师 / 魔导师 / 大魔导师）—— 阶就是晶石的品（下 / 中 / 上 / 两颗上）；
## 装着在供给的魔晶石的法杖出手不耗耐力（[member AbilityRule.free_when_loaded]），空杖照旧扣五
extends RefCounted

const B211 := preload("res://tests/enemies/test_builds_211.gd")
const C148 := preload("res://tests/run/test_crystal_148.gd")

const MAGES := [[&"apprentice_mage", "魔法学徒", "Apprentice Mage", 2, 32], [&"adept_mage", "熟练的魔法师", "Adept Mage", 3, 44],
	[&"magus", "魔导师", "Magus", 3, 56], [&"grand_magus", "大魔导师", "Grand Magus", 3, 72]]


static func _tier_of(id: StringName) -> String:
	var s := String(id)
	return "high" if s.ends_with("_high") else ("low" if s.ends_with("_low") else "mid")

## 252：四阶各拿哪根杖
const STAFF_OF := {&"apprentice_mage": &"magic_staff", &"adept_mage": &"mage_staff", &"magus": &"magus_staff", &"grand_magus": &"grand_magus_staff"}

static func run_defs(t: TestCase) -> void:
	t.begin("247 §一：四阶都在库里 —— 名字、本色档位、生命；法杖招牌、魔法流派、人形")
	var c := B211._content()
	for row in MAGES:
		var d := c.enemies.enemy(row[0])
		t.not_null(d, "%s 在库里" % row[0])
		if d == null:
			continue
		t.eq(Names.of(d, "zh"), row[1], "中文名")
		t.eq(Names.of(d, "en"), row[2], "英文名")
		t.eq(d.strength, row[3], "%s 本色档位 %d" % [row[1], row[3]])
		t.eq(float(d.base_stats.get("max_hp", 0)), float(row[4]), "%s 生命 %d" % [row[1], row[4]])
		var staff: StringName = STAFF_OF[row[0]]     # 252 待定 2：四阶各拿对应的杖
		t.check(d.signature.has(staff) and d.schools.has(&"magic") and d.species == &"human", "%s：%s、魔法、人形" % [row[1], staff])


static func run_builds(t: TestCase) -> void:
	t.begin("247 §一：套路的晶石按阶写死 —— 学徒两颗下品（火 + 冰）、熟练两颗中品、魔导师一上一中、大魔导师两颗不同元素的上品")
	var c := B211._content()
	var want := {&"apprentice_mage": ["low", "low"], &"adept_mage": ["mid", "mid"], &"magus": ["high", "mid"], &"grand_magus": ["high", "high"]}
	for id in want:
		var d := c.enemies.enemy(id)
		if d == null:
			continue
		for b in d.builds:
			var tiers: Array = []
			var elems := {}
			for item in (b as EnemyBuild).items:
				var idef := c.items.get_def(item)
				if CrystalRoll.is_rolled(idef):
					tiers.append(_tier_of(item))
					elems[idef.crystal_family] = true
			if id == &"grand_magus":
				t.eq(tiers.count("high"), 2, "大魔导师 %s：两颗上品" % b.id)
				t.check(elems.size() >= 2, "大魔导师 %s：不同元素" % b.id)
			else:
				t.eq(tiers, want[id], "%s %s：%s" % [id, b.id, want[id]])
	var two := c.enemies.enemy(&"apprentice_mage").build_of(&"two_crystals")
	t.eq(two.items, [&"fire_crystal_low", &"ice_crystal_low"] as Array[StringName], "学徒：火 + 冰下品")


static func run_placed(t: TestCase) -> void:
	t.begin("247 §四：摆出来晶石落在法杖的装载格上，套路的品不换（写死），次数随机")
	var c := B211._content()
	var loaded := 0
	for s in 8:
		for id in [&"apprentice_mage", &"grand_magus"]:
			var mage := c.enemies.enemy(id)
			var forced := B211._forced(mage, c.pool, mage.builds[0].id)
			var built := B211._build(forced, c, 3, 470 + s)
			var content: Dictionary = built["content"]
			var ids := B211._ids(content, c.items)
			for want in forced.builds[0].items:     # 套路写的那几颗原样在（余数照抽来的晶石照常换品）
				t.check(B211._count(ids, want) >= B211._count(forced.builds[0].items, want), "%s：套路的 %s 没被换品" % [id, want])
			for raw in content["items"]:
				var e := raw as Dictionary
				if CrystalRoll.is_rolled(c.items.get_def(StringName(String(e["id"])))):
					t.check(int(e.get("charges", 0)) >= 1, "%s：%s 记了次数" % [id, e["id"]])
			if B211._crystal_loaded(content, c):
				loaded += 1
	t.check(loaded >= 8, "晶石在装载格上：%d / 16" % loaded)


static func run_pool(t: TestCase) -> void:
	t.begin("247 §一：池 —— 四条权重 2 / 1.5 / 1 / 0.6；外环抽不到；大魔导师只在核心环；魔导师只进精英点")
	var c := B211._content()
	var rows := {}
	for e in c.pool.entries:
		rows[(e as EnemyPoolEntry).enemy] = e
	var weights: Array[float] = []
	for row in MAGES:
		t.check(rows.has(row[0]), "%s 在池里" % row[0])
		if rows.has(row[0]):
			weights.append((rows[row[0]] as EnemyPoolEntry).weight)
			t.check(not (rows[row[0]] as EnemyPoolEntry).kinds.has(&"outskirts"), "%s：外环没有" % row[0])
	t.eq(weights, [2.0, 1.5, 1.0, 0.6] as Array[float], "权重")
	if rows.has(&"grand_magus"):
		t.check(not (rows[&"grand_magus"] as EnemyPoolEntry).kinds.has(&"depths"), "大魔导师：深处没有")
	if rows.has(&"magus"):
		t.eq((rows[&"magus"] as EnemyPoolEntry).node_types, [&"elite"] as Array[StringName], "魔导师：精英点")
	var node := MapNode.new()
	node.type = &"battle"
	node.layout = {"kind": "outskirts"}
	for e in EnemyPlacer.candidates(c.pool, c.enemies, node, 0):
		t.check(not [&"apprentice_mage", &"adept_mage", &"magus", &"grand_magus"].has((e as EnemyPoolEntry).enemy), "外环档 0 候选里没有法师（%s）" % e.enemy)


static func _stamina_spent(board: GridInventory) -> Dictionary:
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var foe := BattleCompiler.compile(null, foe_in)
	var me := BattleCompiler.compile_board(board, CombatantBaseline.with_hp(4000.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var res := BattleSim.run(me, foe, rng, 6.0)
	var spent := 0
	var fired := 0
	for ev in res.log:
		var e := ev as BattleEvent
		if e.side == 0 and e.name == BattleEvent.RESOURCE_CHANGED and e.get_name(&"key") == &"stamina" and e.get_int(&"delta") < 0:
			spent -= e.get_int(&"delta")
		elif e.side == 0 and e.name == BattleEvent.ITEM_FIRED:
			fired += 1
	return {"spent": spent, "fired": fired}


static func run_free_staff(t: TestCase) -> void:
	t.begin("247 §二：装着晶石的法杖出手不耗耐力；空杖照旧扣；碎了的晶石不算装着")
	var db := C148._db()
	var rule := db.get_def(&"magic_staff").combat.rules[0] as AbilityRule
	t.check(rule.free_when_loaded, "法杖的出手规则打开了 free_when_loaded")
	var loaded := _stamina_spent(C148._staff_board(db, &"fire_crystal", &"")["board"])
	t.check(int(loaded["fired"]) > 0, "装着晶石：出手了 %d 次" % loaded["fired"])
	t.eq(int(loaded["spent"]), 0, "装着晶石：耐力一点没扣")
	var empty := _stamina_spent(C148._staff_board(db, &"", &"")["board"])
	t.check(int(empty["fired"]) > 0 and int(empty["spent"]) > 0, "空杖：扣了耐力（%s）" % StatMath.to_float(int(empty["spent"])))
	var broken := C148._staff_board(db, &"fire_crystal", &"")
	(broken["left"] as ItemInstance).state[WearProfile.CHARGES_KEY] = 0
	t.check(int(_stamina_spent(broken["board"])["spent"]) > 0, "碎了的晶石不算：照扣")
	var stats := BattleCompiler.compile_board(C148._staff_board(db, &"fire_crystal", &"")["board"])
	var text := TextTemplate.strip_bbcode(ItemTooltip.describe(C148._staff_board(db, &"fire_crystal", &"")["staff"], C148._staff_board(db, &"fire_crystal", &"")["board"]))
	t.check(stats != null and text.contains("不耗耐力"), "悬浮窗写装着晶石不耗耐力")
