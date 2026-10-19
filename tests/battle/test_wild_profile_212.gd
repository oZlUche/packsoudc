## 212（作者 21:30 夜间六条之六，待定按推荐）：一件道具两套逻辑 —— 玩家持有用 combat / 邻接 / applies，
## 魔兽持有（CompileInput.wild）用 wild + wild_applies，不跑邻接、信仰、applies
extends RefCounted


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


## 匕首（竖 1×2）在 (0,0)，火焰腺在 (0,2)：腺体的增益格（上下）罩着匕首下面那一格
static func _board(db: ItemDatabase, other: StringName = &"fire_gland") -> Dictionary:
	var board := GridInventory.new(Vector2i(3, 3), 0, false)
	var knife := ItemInstance.create(db.get_def(&"knife"))
	var organ := ItemInstance.create(db.get_def(other))
	board.place(knife, Vector2i(0, 0), 0)
	board.place(organ, Vector2i(0, 2), 0)
	return {"board": board, "knife": knife, "organ": organ}


static func _compile(board: GridInventory, wild: bool) -> CombatantSpec:
	var inp := CompileInput.new()
	inp.wild = wild
	return BattleCompiler.compile(board, inp)


static func _origins(item: CompiledItem) -> Array:
	var out: Array = []
	for a in item.attached:
		out.append(StringName(String(a["origin"])))
	return out


static func run_two_faces(t: TestCase) -> void:
	t.begin("212 · ① 火焰腺：玩家持有 = 给相邻武器挂「出手施加灼伤」、自己不出手；魔兽持有 = 自己每 1.5 秒打火伤、打中施加灼伤，不给匕首挂")
	var db := _db()
	var b := _board(db)
	var player := _compile(b["board"], false)
	var pk := player.item_of((b["knife"] as ItemInstance).uid)
	var pg := player.item_of((b["organ"] as ItemInstance).uid)
	t.check(_origins(pk).has(&"fire_gland"), "玩家：匕首挂上了腺体给的规则（%s）" % [_origins(pk)])
	t.eq(pg.rules.size(), 0, "玩家：腺体自己没有规则")
	var wild := _compile(b["board"], true)
	var wk := wild.item_of((b["knife"] as ItemInstance).uid)
	var wg := wild.item_of((b["organ"] as ItemInstance).uid)
	t.eq(_origins(wk), [], "魔兽：匕首没有附加（不跑邻接）")
	t.check(wg.rules.size() >= 2, "魔兽：腺体自己出手 + 打中施加（%d 条）" % wg.rules.size())
	t.check(wg.rules[0].trigger is OnSchedule and wg.rules[0].cadence is CooldownCadence, "第一条是自发、冷却")
	t.eq((wg.rules[0].cadence as CooldownCadence).seconds, 1.5, "每 1.5 秒")
	var dd := wg.rules[0].effects[0] as DealDamage
	t.check(dd != null and dd.damage_type == &"fire", "打的是火伤")
	t.eq(wg.stats.total_of(BattleStats.DAMAGE), StatMath.from_float(4.0), "伤害 4")
	t.check(_origins(wg).has(ElementApply.ORIGIN), "打中施加走 applies 那个入口（wild_applies）")
	var applied := ""
	for a in wg.attached:
		var r := wg.rules[int(a["rule_index"])] as AbilityRule
		for e in r.effects:
			if e is ApplyStatus:
				applied = String((e as ApplyStatus).buff.id)
	t.eq(applied, "scorch", "施加的是灼伤")


static func run_wild_skips_player_parts(t: TestCase) -> void:
	t.begin("212 · ② 魔兽持有时邻接加成、applies 都不算；没写 wild 的道具两边一样")
	var db := _db()
	var b := _board(db, &"beast_fang")
	# 兽牙的增益格在左右；摆到匕首右边
	var board := GridInventory.new(Vector2i(3, 3), 0, false)
	var knife := ItemInstance.create(db.get_def(&"knife"))
	var fang := ItemInstance.create(db.get_def(&"beast_fang"))
	board.place(knife, Vector2i(0, 0), 0)
	board.place(fang, Vector2i(1, 0), 0)
	var player := _compile(board, false)
	var wild := _compile(board, true)
	t.eq(player.item_of(knife.uid).stats.total_of(BattleStats.DAMAGE), StatMath.from_float(4.0), "玩家：匕首 3 + 兽牙 1")
	t.eq(wild.item_of(knife.uid).stats.total_of(BattleStats.DAMAGE), StatMath.from_float(3.0), "魔兽：不跑邻接，匕首 3")
	t.eq(wild.item_of(fang.uid).stats.total_of(BattleStats.DAMAGE), StatMath.from_float(6.0), "魔兽：兽牙自己咬 6")
	t.eq(player.item_of(knife.uid).rules.size(), wild.item_of(knife.uid).rules.size(), "匕首没写 wild：两边规则一样")
	var applies := ItemDef.new()
	applies.id = &"t_applies"
	applies.shape = ItemShape.from_ascii(["1"])
	applies.combat = (db.get_def(&"knife") as ItemDef).combat
	var ea := ElementApply.new()
	ea.buff = ContentLibrary.buffs()[&"scorch"]
	applies.applies = [ea] as Array[ElementApply]
	var solo := GridInventory.new(Vector2i(1, 1), 0, false)
	var inst := ItemInstance.create(applies)
	solo.place(inst, Vector2i.ZERO, 0)
	t.check(_origins(_compile(solo, false).item_of(inst.uid)).has(ElementApply.ORIGIN), "玩家：applies 挂上")
	t.eq(_origins(_compile(solo, true).item_of(inst.uid)), [], "魔兽：applies 不挂（它没有 wild_applies）")
	t.check(b["board"] != null, "（兽牙两面都在）")


static func run_patched_materials(t: TestCase) -> void:
	t.begin("212 · ③ 六件兽材补了 wild；六件新器官都是【自然】、带兽材标签；元素器官带元素标签")
	var db := _db()
	for id in [&"beast_hide", &"fine_fur", &"wolf_heart", &"viper_gland", &"antler", &"beast_tusk_root"]:
		var d := db.get_def(id)
		t.check(d != null and d.wild != null and d.tags.has(&"beast_part"), "%s：有 wild、带兽材" % id)
	for pair in [[&"fire_gland", &"fire"], [&"frost_gland", &"ice"], [&"shock_sac", &"lightning"],
			[&"beast_fang", &""], [&"beast_claw", &"bleed"], [&"beast_tail", &""]]:
		var d := db.get_def(pair[0])
		t.check(d != null and d.tags.has(&"nature") and d.tags.has(&"beast_part") and not d.tags.has(&"magic"), "%s：自然、兽材、不是魔法" % pair[0])
		if pair[1] != &"":
			t.check(d.tags.has(pair[1]), "%s 带 %s" % pair)
	var viper := db.get_def(&"viper_gland")
	t.eq(viper.wild_applies.size(), 1, "蝰蛇毒腺：魔兽咬人施加中毒")
	t.eq(viper.wild_applies[0].stacks, 2, "两层")
	for r in viper.wild.rules:
		for e in (r as AbilityRule).effects:
			if e is DealDamage:
				t.check((e as DealDamage).damage_type != &"poison", "毒没有直接伤害形态（107）：毒腺咬的是物理")


static func run_import(t: TestCase) -> void:
	t.begin("212 · ④ 导入：wild 写在包上提醒；wild 里耗耐力不报「耐力只归武器」；三个施加宏在")
	var ctx := ContentImporter.Context.new()
	var bag := ImportReport.new()
	ContentImporter.import_item({"id": "t_wild_bag", "shape": ["11"], "is_bag": true, "wild": {"base_stats": {"max_hp": 3}}}, ctx, bag)
	t.check(bag.to_text().contains("魔兽没有包"), "包上写 wild：提醒（%s）" % bag.to_text())
	var organ := ImportReport.new()
	ContentImporter.import_item({"id": "t_wild_organ", "shape": ["1"], "wild": {"base_stats": {"damage": 2}, "rules": [{
		"trigger": {"type": "on_schedule"}, "cadence": {"type": "cooldown", "seconds": 1.0},
		"costs": [{"type": "resource", "amount": 3.0}], "effects": [{"type": "deal_damage"}]}]}}, ctx, organ)
	t.check(organ.ok() and not organ.to_text().contains("耐力只归武器"), "器官的 wild 耗耐力：不报（%s）" % organ.to_text())
	for id in ["scorch", "chill", "numb"]:
		var part = load(ContentPaths.asset_file("rule_parts", "apply_status_" + id))
		t.check(part != null and String((part as RulePartDef).effect.buff.id) == id, "@apply_status_%s → 施加 %s" % [id, id])
