## 273（作者 2026-11-04）：法杖按稀有度乘威力系数 —— 白 1.0 / 绿 1.15 / 蓝 1.3 / 紫 1.45（方案 1.2 / 1.4 / 1.6，待定 2 回调）；
## 一下 = (杖基础 + 这颗晶石的加值) × 系数，向下取整；没装晶石的木棍 = 基础 × 系数；晶石加值 7 / 10 / 14
extends RefCounted

const Cycle := preload("res://tests/battle/test_staff_cycle_175.gd")

const MULTS := {&"magic_staff": 1.0, &"mage_staff": 1.15, &"magus_staff": 1.3, &"grand_magus_staff": 1.45}     # 方案待定 2：台架里法师压过近战，回调
const CRYSTALS := {"_low": 7.0, "": 10.0, "_high": 14.0}


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 一把杖在 (2,0)，可选一颗晶石在左边 (0,0)
static func _board(db: ItemDatabase, staff_id: StringName, crystal: StringName) -> Dictionary:
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(5, 3), 1, false)
	var staff := ItemInstance.create(db.get_def(staff_id))
	g.place(staff, Vector2i(2, 0), 0)
	if crystal != &"":
		g.place(ItemInstance.create(db.get_def(crystal)), Vector2i(0, 0), 0)
	return {"board": g, "staff": staff}


static func run_data(t: TestCase) -> void:
	t.begin("273 · 数据：四把杖的威力系数、九颗晶石的加值、描述只在有系数的杖上写「威力 ×N」")
	UiText.lang = "zh"
	var db := _db()
	for id in MULTS:
		var def := db.get_def(id)
		t.eq(def.combat.power_mult, float(MULTS[id]), "%s 威力 ×%s" % [id, MULTS[id]])
		var spec := BattleCompiler.compile_board(_board(db, id, &"")["board"])
		t.eq(spec.items[0].power_mult, StatMath.from_float(float(MULTS[id])), "%s 编译后带上系数" % id)
		var desc := TextTemplate.render(Names.description_of(def))
		var shown := desc.contains("威力 ×")
		t.eq(shown, float(MULTS[id]) != 1.0, "%s 描述%s写威力" % [id, "" if shown else "不"])
		if shown:
			t.check(TextTemplate.plain(Names.description_of(def)).contains("威力 ×%s" % MULTS[id]), "%s 描述里的数：%s" % [id, desc])
	for el in ["fire", "ice", "lightning"]:
		for suffix in CRYSTALS:
			var c := db.get_def(StringName("%s_crystal%s" % [el, suffix]))
			t.eq((c.adjacency.feed_mods[0] as StatModifier).amount, float(CRYSTALS[suffix]), "%s 加 %s" % [c.id, CRYSTALS[suffix]])
	t.eq(CombatProfile.new().power_mult, 1.0, "不写 = ×1")


static func run_hits(t: TestCase) -> void:
	t.begin("273 · 战斗：一下 = (基础 + 晶石) × 系数向下取整；木棍 = 基础 × 系数；白杖不变")
	var db := _db()
	for id in MULTS:
		var mult := float(MULTS[id])
		var base := float(db.get_def(id).combat.base_stats["damage"])
		var stick := _board(db, id, &"")
		var s0 := Cycle._shots(Cycle._compile(stick["board"], stick["staff"].uid), stick["staff"].uid)
		t.check(s0.size() >= 1, "%s 木棍打了（%d 下）" % [id, s0.size()])
		if s0.size() >= 1:
			t.eq(float(s0[0][2]), floorf(base * mult + 0.0001), "%s 木棍：floor(%s × %s)" % [id, base, mult])
		var lit := _board(db, id, &"fire_crystal")
		var s1 := Cycle._shots(Cycle._compile(lit["board"], lit["staff"].uid), lit["staff"].uid)
		t.check(s1.size() >= 1, "%s 带火晶石打了（%d 下）" % [id, s1.size()])
		if s1.size() >= 1:
			t.eq(String(s1[0][1]), "fire", "%s：火焰" % id)
			t.eq(float(s1[0][2]), floorf((base + 10.0) * mult + 0.0001), "%s：floor((%s + 10) × %s)" % [id, base, mult])


static func run_tooltip(t: TestCase) -> void:
	t.begin("273 · 提示：轮读那一行写乘过系数的数")
	UiText.lang = "zh"
	var db := _db()
	var lit := _board(db, &"mage_staff", &"fire_crystal")
	var spec := Cycle._compile(lit["board"], lit["staff"].uid)
	var item := spec.item_of(lit["staff"].uid)
	var base := StatMath.to_float(item.stats.total_of(BattleStats.DAMAGE))
	var want := int(floorf((base + 10.0) * 1.15 + 0.0001))
	var shots := ItemTooltip.cycle_shots(item.rules[0], item.stats, item.loaded, ItemTooltip.power_of(null, item))
	t.check(shots.size() == 1 and TextTemplate.plain(shots[0]).contains(str(want)), "绿杖 + 火晶石：%d（%s）" % [want, str(shots)])
	var plain := ItemTooltip.cycle_shots(item.rules[0], item.stats, item.loaded)
	t.check(plain.size() == 1 and TextTemplate.plain(plain[0]).contains(str(int(base + 10.0))), "不给系数 = ×1（%s）" % str(plain))
