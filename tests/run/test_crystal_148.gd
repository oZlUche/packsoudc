## 148（作者定，五项待定按推荐）：魔晶石是法杖的弹药 —— 晶石站在法杖的受益格上「供给」：伤害 +N、这件打出的伤害改成本元素；
## 耐久记在实例上（满 3 次），每场战斗结束点亮过的 −1，归零 = 破碎（不再供给、卖价打折）；名字前缀看剩几次。晶石不再给魔力
extends RefCounted

const CS := preload("res://tests/run/test_character_skills.gd")


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _damage(spec: CombatantSpec, uid: int) -> float:
	return StatMath.to_float(spec.item_of(uid).stats.total_of(&"damage"))


## 法杖竖着放在第 2 列（受益格在它头顶那一格的左右：(1, 0) 与 (3, 0)）；[param left] / [param right] 是放在两边的晶石 id（空 = 不放）
static func _staff_board(db: ItemDatabase, left: StringName, right: StringName) -> Dictionary:
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(5, 3), 1, false)
	var staff := ItemInstance.create(db.get_def(&"magic_staff"))
	g.place(staff, Vector2i(2, 0), 0)
	var out := {"board": g, "staff": staff}
	if left != &"":
		var a := ItemInstance.create(db.get_def(left))
		g.place(a, Vector2i(0, 0), 0)
		out["left"] = a
	if right != &"":
		var b := ItemInstance.create(db.get_def(right))
		g.place(b, Vector2i(3, 0), 0)
		out["right"] = b
	return out


static func run_feed_compile(t: TestCase) -> void:
	t.begin("148 · 编译：法杖独自是木棍；挨着晶石记进轮读表（175：伤害与换型轮到它才用）、记进 fed；破碎的不给；不是法杖的宿主不给")
	var db := _db()
	var staff_def := db.get_def(&"magic_staff")
	var base := float(staff_def.combat.base_stats["damage"])
	var fire := db.get_def(&"fire_crystal")
	var plus := (fire.adjacency.feed_mods[0] as StatModifier).amount
	t.check(fire.combat == null, "晶石不再给魔力（没有战斗档）")
	var alone := _staff_board(db, &"", &"")
	var s0 := BattleCompiler.compile_board(alone["board"])
	t.eq(_damage(s0, alone["staff"].uid), base, "独自：伤害 %s" % base)
	t.eq(s0.item_of(alone["staff"].uid).attached.size(), 0, "独自：没有附加规则")

	# 175 第二批：轮读的法杖，晶石的伤害与换型不再常驻 —— 记进 loaded，轮到它那一下才用
	var one := _staff_board(db, &"fire_crystal", &"")
	var s1 := BattleCompiler.compile_board(one["board"])
	var staff1 := s1.item_of(one["staff"].uid)
	t.eq(_damage(s1, one["staff"].uid), base, "一颗：属性上的伤害不变（%s）" % base)
	t.eq(staff1.attached.size(), 0, "换型不再常驻挂着")
	t.eq(staff1.loaded.size(), 1, "轮读表一颗")
	t.eq(String(staff1.loaded[0]["type"]), "fire", "这颗打火焰")
	t.eq(StatMath.to_float(int(staff1.loaded[0]["damage"])), plus, "这颗加 %s" % plus)
	t.eq(s1.fed_uids, [one["left"].uid] as Array[int], "fed 记下这颗晶石")
	t.check(staff1.linked_uids.has(one["left"].uid), "法杖和晶石连着")

	var two := _staff_board(db, &"fire_crystal", &"ice_crystal")
	var s2 := BattleCompiler.compile_board(two["board"])
	t.eq(_damage(s2, two["staff"].uid), base, "两颗：属性上的伤害仍不变")
	t.eq(s2.item_of(two["staff"].uid).loaded.size(), 2, "轮读表两颗")

	var broken := _staff_board(db, &"fire_crystal", &"")
	(broken["left"] as ItemInstance).spend_charge((broken["left"] as ItemInstance).def.wear.max_charges)
	t.check((broken["left"] as ItemInstance).is_broken(), "扣满次数：碎了")
	var sb := BattleCompiler.compile_board(broken["board"])
	t.eq(_damage(sb, broken["staff"].uid), base, "破碎的不再供给")
	t.eq(sb.item_of(broken["staff"].uid).loaded.size(), 0, "轮读表里没有它")
	t.eq(sb.fed_uids.size(), 0, "fed 里没有它")

	# 不是法杖的宿主：受益格收晶石也不给（feed_filter = staff）
	ItemInstance.reset_uid_counter()
	var g := GridInventory.new(Vector2i(5, 3), 1, false)
	var host_def := staff_def.duplicate(true) as ItemDef
	host_def.id = &"not_a_staff"
	host_def.tags = [&"weapon", &"melee"] as Array[StringName]
	var host := ItemInstance.create(host_def)
	g.place(host, Vector2i(2, 0), 0)
	g.place(ItemInstance.create(fire), Vector2i(0, 0), 0)
	var sh := BattleCompiler.compile_board(g)
	t.eq(_damage(sh, host.uid), base, "宿主没有【法杖】：不给")


static func run_feed_battle(t: TestCase) -> void:
	t.begin("148 · 打起来：挨着火焰魔晶石的法杖打出火焰伤害；冰霜 / 闪电同理；同一边别的武器不受影响；没有晶石是物理")
	var db := _db()
	var foe_in := CompileInput.new()
	foe_in.baseline = CombatantBaseline.with_hp(4000.0)
	var foe := BattleCompiler.compile(null, foe_in)
	for pair in [[&"fire_crystal", "fire"], [&"ice_crystal", "ice"], [&"lightning_crystal", "lightning"], [&"", "physical"]]:
		var b := _staff_board(db, pair[0], &"")
		var knife := ItemInstance.create(db.get_def(&"knife"))
		(b["board"] as GridInventory).try_add(knife)
		var me := BattleCompiler.compile_board(b["board"], CombatantBaseline.with_hp(4000.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var res := BattleSim.run(me, foe, rng, 8.0)
		var staff_types := {}
		var knife_types := {}
		for ev in res.log:
			var e := ev as BattleEvent
			if e.name != BattleEvent.DAMAGE or e.side != 1:
				continue
			var uid := int(e.payload.get("uid", -1))
			if uid == (b["staff"] as ItemInstance).uid:
				staff_types[String(e.payload.get("type", ""))] = true
			elif uid == knife.uid:
				knife_types[String(e.payload.get("type", ""))] = true
		t.eq(staff_types.keys(), [pair[1]], "%s：法杖打出 %s 伤害" % [pair[0] if pair[0] != &"" else "没有晶石", pair[1]])
		t.eq(knife_types.keys(), ["physical"], "小刀照旧物理")


static func run_wear(t: TestCase) -> void:
	t.begin("148 · 耐久：新的一件满 3 次；打一场点亮过的 −1、没点亮的不动、秒杀不扣；前缀四态（中英）；破碎卖价打折；存档与带入往返保留次数，老档按满算")
	var c := CS._content()
	var s := CS._start(c, null)
	if s == null:
		t.check(false, "开不了局")
		return
	t.not_null(WearModule.of(s), "默认装了耐久模块")
	var b := _staff_board(c.items, &"fire_crystal", &"")
	var lit := b["left"] as ItemInstance
	var idle := ItemInstance.create(c.items.get_def(&"ice_crystal"))
	(b["board"] as GridInventory).place(idle, Vector2i(0, 2), 0)
	t.eq(lit.charges(), lit.def.wear.max_charges, "新的一件满 %d 次" % lit.def.wear.max_charges)
	s.board = b["board"]
	var node := CS._battle_node(s)
	s.events.last_battle = {"player": s.compile_player(), "node": node.id}
	s.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(lit.charges(), lit.def.wear.max_charges - 1, "点亮过的 −1")
	t.eq(idle.charges(), idle.def.wear.max_charges, "没点亮的不动")
	s.events.last_battle = {"player": s.compile_player(), "node": node.id, "smite": true}
	s.events.battle_finished.emit(node, BattleResult.new(), true)
	t.eq(lit.charges(), lit.def.wear.max_charges - 1, "秒杀不扣")

	var names: Array[String] = []
	var en: Array[String] = []
	var probe := ItemInstance.create(c.items.get_def(&"fire_crystal"))
	for left in [3, 2, 1, 0]:
		probe.state[WearProfile.CHARGES_KEY] = left
		names.append(Names.of_item(probe, "zh"))
		en.append(Names.of_item(probe, "en"))
	t.eq(names, ["明亮的火焰魔晶石", "闪烁的火焰魔晶石", "黯淡的火焰魔晶石", "破碎的火焰魔晶石"] as Array[String], "前缀按剩几次")
	t.eq(en, ["Bright Fire Crystal", "Flickering Fire Crystal", "Dim Fire Crystal", "Shattered Fire Crystal"] as Array[String], "英文前缀")
	t.eq(Names.of_item(ItemInstance.create(c.items.get_def(&"knife")), "zh"), Names.of(c.items.get_def(&"knife"), "zh"), "没有耐久的：名字不变")
	var full := ItemValue.of(probe.def)
	t.eq(ItemValue.of_instance(probe), maxi(1, int(roundf(full * probe.def.wear.broken_value_ratio))), "破碎：卖价 × %s" % probe.def.wear.broken_value_ratio)
	probe.state[WearProfile.CHARGES_KEY] = 1
	t.eq(ItemValue.of_instance(probe), full, "没碎：原价")

	var round_trip := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(probe.to_dict())), c.items)
	t.eq(round_trip.charges(), 1, "存档（JSON）往返：还剩 1 次")
	t.eq(JSON.stringify(round_trip.to_dict()), JSON.stringify(probe.to_dict()), "再存一次逐字节相同（次数还是整数）")
	var old := probe.to_dict()
	(old["state"] as Dictionary).clear()
	t.eq(ItemInstance.from_dict(old, c.items).charges(), probe.def.wear.max_charges, "老档没记：按满算")
	var layout := RunState.layout_of(b["board"])
	var g2 := GridInventory.new(Vector2i(5, 3), 1, false)
	RunState.place_layout(g2, layout, c.items)
	var carried := -1
	for inst in g2.items():
		if (inst as ItemInstance).def.id == &"fire_crystal":
			carried = (inst as ItemInstance).charges()
	t.eq(carried, lit.charges(), "开局带入（layout）保留次数")
	t.check(ItemTooltip.describe(lit, b["board"]).contains("耐久 %d / %d" % [lit.charges(), lit.def.wear.max_charges]), "悬浮窗写耐久")
