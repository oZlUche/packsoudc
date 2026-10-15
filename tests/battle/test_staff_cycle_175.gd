## 175 第二批（作者定）：法杖没有晶石读基础属性（木棍）；有晶石按顺时针逐颗读，颗间单次冷却、一轮读完总冷却；
## 只装一颗没有单次冷却；两种冷却都吃急速；供给次数按场扣；一颗晶石压两把杖只给后放的那把（171 不变，见 test_staff_load_171）
extends RefCounted

const Staff := preload("res://tests/run/test_crystal_148.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 编好的一方：暴击率归零（数值好比），[param haste] 是法杖的急速倍率
static func _compile(board: GridInventory, staff_uid: int, haste: float = 1.0) -> CombatantSpec:
	var spec := BattleCompiler.compile_board(board, CombatantBaseline.with_hp(4000.0))
	var st := spec.item_of(staff_uid).stats
	st.ensure(BattleStats.CRIT_CHANCE).base = 0
	if haste != 1.0:
		st.ensure(BattleStats.HASTE).base = StatMath.from_float(haste)
	return spec


## 打一场，按时间顺序返回法杖的每一下：[时刻（秒）, 伤害类型, 原值, 出手事件的 payload]
static func _shots(spec: CombatantSpec, staff_uid: int, seconds: float = 5.0) -> Array:
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var foe := BattleCompiler.compile(null, foe_in)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var res := BattleSim.run(spec, foe, rng, seconds)
	var out: Array = []
	var fired := {}
	for ev in res.log:
		var e := ev as BattleEvent
		if e.name == BattleEvent.ITEM_FIRED and e.side == 0 and int(e.payload.get("uid", -1)) == staff_uid:
			fired = e.payload
		elif e.name == BattleEvent.DAMAGE and e.side == 1 and int(e.payload.get("uid", -1)) == staff_uid:
			out.append([StatMath.to_float(e.time), String(e.payload.get("type", "")), StatMath.to_float(int(e.payload.get("raw", 0))), fired])
	return out


static func _gaps(shots: Array, n: int) -> Array[float]:
	var out: Array[float] = []
	for i in range(1, mini(n + 1, shots.size())):
		out.append(snappedf(float(shots[i][0]) - float(shots[i - 1][0]), 0.01))
	return out


static func run_empty_and_one(t: TestCase) -> void:
	t.begin("175 · 法杖：没放晶石是木棍（物理、基础伤害、只有总冷却）；一颗只有总冷却、打它的元素、伤害加它的")
	var db := _db()
	var staff_def := db.get_def(&"magic_staff")
	var base := float(staff_def.combat.base_stats["damage"])
	var plus := (db.get_def(&"fire_crystal").adjacency.feed_mods[0] as StatModifier).amount
	var total := (staff_def.combat.rules[0].cadence as CooldownCadence).seconds
	t.check(staff_def.combat.rules[0].cadence is CycleCadence, "法杖的节奏是轮读")

	var alone := Staff._staff_board(db, &"", &"")
	var s0 := _shots(_compile(alone["board"], alone["staff"].uid), alone["staff"].uid)
	t.check(s0.size() >= 3, "木棍打了几下（%d）" % s0.size())
	if s0.size() >= 3:
		t.eq(String(s0[0][1]), "physical", "木棍：物理")
		t.eq(float(s0[0][2]), base, "木棍：基础伤害 %s" % base)
		t.eq(_gaps(s0, 2), [total, total] as Array[float], "木棍：每下隔总冷却 %s 秒" % total)
		t.check(not (s0[0][3] as Dictionary).has("steps"), "没装晶石：出手事件不带轮次")

	var one := Staff._staff_board(db, &"fire_crystal", &"")
	var s1 := _shots(_compile(one["board"], one["staff"].uid), one["staff"].uid)
	t.check(s1.size() >= 3, "一颗打了几下（%d）" % s1.size())
	if s1.size() >= 3:
		t.eq(String(s1[0][1]), "fire", "一颗：火焰")
		t.eq(float(s1[0][2]), base + plus, "一颗：%s + %s" % [base, plus])
		t.eq(_gaps(s1, 2), [total, total] as Array[float], "一颗：没有单次冷却，每下都隔总冷却")


static func run_two_clockwise(t: TestCase) -> void:
	t.begin("175 · 法杖两颗：从 12 点起顺时针（右边那颗先），颗间单次冷却、一轮后总冷却；出手事件带第几颗；急速同时缩短两种")
	var db := _db()
	var cad := db.get_def(&"magic_staff").combat.rules[0].cadence as CycleCadence
	var b := Staff._staff_board(db, &"fire_crystal", &"ice_crystal")     # 左火、右冰
	var uid: int = b["staff"].uid
	var spec := _compile(b["board"], uid)
	var item := spec.item_of(uid)
	t.eq(item.loaded.size(), 2, "轮读表两颗")
	if item.loaded.size() == 2:
		t.eq(int(item.loaded[0]["uid"]), (b["right"] as ItemInstance).uid, "第一颗是右边（1 点半方向）")
		t.eq(int(item.loaded[1]["uid"]), (b["left"] as ItemInstance).uid, "第二颗是左边（10 点半方向）")
	t.eq(StatMath.to_int(item.stats.total_of(BattleStats.LOAD_STEPS)), 2, "法杖记一轮两下")
	var s := _shots(spec, uid)
	var types: Array[String] = []
	for x in s.slice(0, 4):
		types.append(String(x[1]))
	t.eq(types, ["ice", "fire", "ice", "fire"] as Array[String], "冰 → 火 → 冰 → 火")
	t.eq(_gaps(s, 3), [cad.step_seconds, cad.seconds, cad.step_seconds] as Array[float], "颗间 %s、一轮后 %s" % [cad.step_seconds, cad.seconds])
	if s.size() >= 2:
		var p0 := s[0][3] as Dictionary
		var p1 := s[1][3] as Dictionary
		t.eq([int(p0.get("step", -1)), int(p0.get("steps", -1)), int(p0.get("next", -1))], [0, 2, 1], "第一下：读第 0 颗、一轮两颗、下一下第 1 颗")
		t.eq([int(p1.get("step", -1)), int(p1.get("next", -1))], [1, 0], "第二下：读第 1 颗、下一下回到第 0 颗")

	var fast := _shots(_compile(b["board"], uid, 2.0), uid)
	t.eq(_gaps(fast, 3), [snappedf(cad.step_seconds / 2.0, 0.01), snappedf(cad.seconds / 2.0, 0.01), snappedf(cad.step_seconds / 2.0, 0.01)] as Array[float], "急速 ×2：两种冷却都减半")
	t.eq(spec.fed_uids.size(), 2, "两颗都记 fed（供给次数按场扣，148）")


## 测试用的法杖：竖放三格，装载槽在头顶、右中、脚下、左中
static func _probe_staff(db: ItemDatabase) -> ItemDef:
	var def := db.get_def(&"magic_staff").duplicate(true) as ItemDef
	def.id = &"probe_cycle_staff"
	def.adjacency.load_cells = [Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 3), Vector2i(-1, 1)] as Array[Vector2i]
	return def


static func run_three_order(t: TestCase) -> void:
	t.begin("175 · 三颗：按方位顺时针排（头顶 → 右 → 脚下），和放的先后无关；一轮三下")
	var db := _db()
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(5, 5), 1, false)
	var staff := ItemInstance.create(_probe_staff(db))
	t.check(g.place(staff, Vector2i(2, 1), 0), "法杖放在中间")
	var bottom := ItemInstance.create(db.get_def(&"ice_crystal"))
	t.check(g.place(bottom, Vector2i(2, 4), 0), "先放脚下（冰）")
	var right := ItemInstance.create(db.get_def(&"fire_crystal"))
	t.check(g.place(right, Vector2i(3, 2), 0), "再放右边（火）")
	var top := ItemInstance.create(db.get_def(&"lightning_crystal"))
	t.check(g.place(top, Vector2i(2, 0), 0), "最后放头顶（雷）")
	var spec := _compile(g, staff.uid)
	var order: Array[int] = []
	for e in spec.item_of(staff.uid).loaded:
		order.append(int(e["uid"]))
	t.eq(order, [top.uid, right.uid, bottom.uid] as Array[int], "头顶 → 右 → 脚下")
	var s := _shots(spec, staff.uid, 6.0)
	var types: Array[String] = []
	for x in s.slice(0, 4):
		types.append(String(x[1]))
	t.eq(types, ["lightning", "fire", "ice", "lightning"] as Array[String], "雷 → 火 → 冰 → 雷")
	var cad := spec.item_of(staff.uid).rules[0].cadence as CycleCadence
	# 175 补充四：雷 → 火引发过载，自己多一层加速 —— 一轮后的总冷却按那一刻的攻速算（快照语义）
	var haste := 1.0 + StatAxes.step_of(StatAxes.ATTACK_SPEED) / 100.0
	t.eq(_gaps(s, 3), [cad.step_seconds, cad.step_seconds, snappedf(cad.seconds / haste, 0.01)] as Array[float], "颗间、颗间、一轮后（过载加速一层）")


static func run_estimate_and_text(t: TestCase) -> void:
	t.begin("175 · 估算与悬浮窗：一秒几下按一轮 n 下 / (n−1)×单次 + 总；三种写法；装载行带罗马数字；回放标下一颗")
	var db := _db()
	var cad := db.get_def(&"magic_staff").combat.rules[0].cadence as CycleCadence
	var st := StatSet.new()
	t.check(is_equal_approx(cad.estimated_hz(st), 1.0 / cad.seconds), "没装：1 / 总")
	st.ensure(BattleStats.LOAD_STEPS).base = 2 * StatMath.ONE
	t.check(is_equal_approx(cad.estimated_hz(st), 2.0 / (cad.step_seconds + cad.seconds)), "两颗：2 / (单次 + 总)")

	var alone := Staff._staff_board(db, &"", &"")
	t.check(Glossary.strip_bbcode(ItemTooltip.describe(alone["staff"], alone["board"])).contains("没放晶石：物理"), "空杖：没放晶石：物理 Y，每 Z 秒")
	var one := Staff._staff_board(db, &"fire_crystal", &"")
	var one_text := Glossary.strip_bbcode(ItemTooltip.describe(one["staff"], one["board"]))
	t.check(one_text.contains("装载一颗：火") and not one_text.contains("颗间"), "一颗：装载一颗：火 Y，每 Z 秒（%s）" % one_text)
	var two := Staff._staff_board(db, &"fire_crystal", &"ice_crystal")
	var two_text := Glossary.strip_bbcode(ItemTooltip.describe(two["staff"], two["board"]))
	t.check(two_text.contains("装载 2 颗，顺时针：冰") and two_text.contains(" → 火"), "两颗：顺时针冰 → 火（%s）" % two_text)
	t.check(two_text.contains("颗间 %s 秒，一轮后歇 %s 秒" % [str(cad.step_seconds), str(cad.seconds)]), "两颗：写两种冷却")
	t.check(two_text.contains("Ⅰ " + Names.of_item(two["right"])) and two_text.contains("Ⅱ " + Names.of_item(two["left"])), "装载行：Ⅰ 右、Ⅱ 左")
	var two_spec := BattleCompiler.compile_board(two["board"])
	var dps := two_spec.item_of(two["staff"].uid).estimated_dps()
	t.check(dps > 0.0, "预估 DPS 算得出（%.2f）" % dps)

	var o := CooldownOverlay.new()
	o.note_step(5, 1, 2)
	t.eq(int(o.steps.get(5, 0)), 2, "回放：下一下第 2 颗 → 标Ⅱ")
	o.note_step(5, 0, 1)
	t.check(not o.steps.has(5), "一轮只有一颗：不标")
	t.eq(TextTemplate.roman(3), "Ⅲ", "罗马数字")
	o.free()
