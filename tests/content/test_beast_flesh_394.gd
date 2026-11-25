## 394（作者 11-25）：【血肉】只是子类标签（素材 → 食材 → 血肉），三件占位换成按野兽分的肉和器官；
## 每种魔兽必掉自己的肉、器官按几率掉；都能下食堂的锅（肉类）；老存档的占位换成蟾腿 / 鳗段 / 熊掌
extends RefCounted

const G388 := preload("res://tests/run/test_god_cards_388.gd")

## 魔兽 → [肉, 器官（没有 = 空）]
const BEASTS := {
	&"flame_wolf": [&"wolf_shank", &"wolf_heart"], &"frost_toad": [&"toad_leg", &""], &"pit_viper": [&"viper_cut", &"viper_gall"],
	&"tusk_boar": [&"boar_belly", &""], &"shock_eel": [&"eel_cut", &""], &"cave_bear": [&"bear_paw", &"bear_liver"],
	&"frost_mane": [&"mane_loin", &""], &"molten_lizard": [&"lizard_tail", &""], &"thunder_vulture": [&"vulture_breast", &""],
	&"miasma_spider": [&"spider_leg_meat", &""],
}
const GENERIC: Array[StringName] = [&"meat_scrap", &"game_meat", &"prime_game_meat", &"beast_haunch", &"beast_ribs", &"prime_beast_leg"]


static func run_tags(t: TestCase) -> void:
	t.begin("394 · 【血肉】是子类标签：带它的同时带【素材】【食材】，都有食堂肉类条目；通用兽肉也贴上；占位没了，老存档换件")
	var db := ItemDatabase.new()
	db.load_dir()
	var tag := ContentPaths.load_asset("tags", "blood_flesh") as TagDef
	t.check(tag != null and tag.parents.has(&"material") and tag.parents.has(&"ingredient"), "血肉的上级是素材、食材")
	var all: Array[StringName] = []
	for e in BEASTS:
		for id in BEASTS[e]:
			if id != &"":
				all.append(id)
	all.append_array(GENERIC)
	for id in all:
		var d := db.get_def(id)
		if d == null:
			t.check(false, "道具库里有 %s" % id)
			continue
		t.check(d.has_tag(BruteRagePerk.FLESH_TAG) and d.has_tag(&"material") and d.has_tag(&"ingredient"), "%s 带血肉、素材、食材" % id)
		t.eq(d.description, "", "%s 说明留空" % id)
		t.eq(Canteen.entry_of(d).get("stat", &""), BattleStats.MAX_STAMINA, "%s 下锅算肉类（耐力上限）" % id)
	for old in [&"blood_flesh_scrap", &"blood_flesh", &"blood_flesh_prime"]:
		t.eq(db.get_def(old), null, "占位 %s 撤掉了" % old)
	t.eq(String(IdAliases.RETIRED_ITEMS[&"blood_flesh_scrap"]["replace"]), "toad_leg", "老存档：碎血肉 → 蟾腿")
	t.eq(String(IdAliases.RETIRED_ITEMS[&"blood_flesh"]["replace"]), "eel_cut", "血肉 → 鳗段")
	t.eq(String(IdAliases.RETIRED_ITEMS[&"blood_flesh_prime"]["replace"]), "bear_paw", "上等血肉 → 熊掌")
	# 进食公式不变：每格 15 ×（稀有度 + 1）
	for pair in [[&"toad_leg", 15.0], [&"eel_cut", 60.0], [&"bear_paw", 135.0]]:
		var d2 := db.get_def(pair[0])
		t.check(d2 != null and is_equal_approx(15.0 * d2.cell_count() * (d2.rarity + 1), pair[1]), "%s 吃下 +%s" % [pair[0], pair[1]])


static func run_drops(t: TestCase) -> void:
	t.begin("394（作者 16:01 改）· 掉落：肉和器官都是战利品、按几率掉（肉 50%、器官 30%），摆不下就不掉；不挤战斗道具")
	var c := TestSupport.load_content("free_mode")
	for e in BEASTS:
		var def := c.enemies.enemy(e)
		if def == null:
			t.check(false, "有 %s" % e)
			continue
		var meat: StringName = BEASTS[e][0]
		var organ: StringName = BEASTS[e][1]
		t.check(def.loot_bonus.is_empty(), "%s 没有必掉的" % e)
		t.check(is_equal_approx(float(def.loot_chance.get(String(meat), 0.0)), 0.5), "%s 的 %s 50%%" % [e, meat])
		if organ != &"":
			t.check(is_equal_approx(float(def.loot_chance.get(String(organ), 0.0)), 0.3), "%s 的 %s 30%%" % [e, organ])
		else:
			t.eq(def.loot_chance.size(), 1, "%s 只有肉" % e)
	for e in [&"flame_wolf", &"pit_viper", &"cave_bear"]:
		var def := c.enemies.enemy(e)
		var meat_n := 0
		var organ_n := 0
		for i in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = 394 * 100 + i
			var items: Array = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)["content"]["items"]
			var ids: Array = items.filter(func(x: Dictionary) -> bool: return bool(x.get("carried", false))).map(func(x: Dictionary) -> String: return String(x["id"]))
			if ids.has(String(BEASTS[e][0])):
				meat_n += 1
			if ids.has(String(BEASTS[e][1])):
				organ_n += 1
		t.check(meat_n > 5 and meat_n < 35, "%s 肉 40 场掉了 %d 次" % [e, meat_n])
		t.check(organ_n > 2 and organ_n < 25, "%s 器官 40 场掉了 %d 次" % [e, organ_n])


static func run_organs(t: TestCase) -> void:
	t.begin("395 · 器官进食不加生命上限、给特性（好处在前），每吃一件叠一次；升级的一半耐力只按肉算；状态界面写合计")
	var run := G388._start(395, &"brute")
	var lv := LevelModule.of(run)
	if lv == null:
		t.check(false, "开局奉蛮神")
		return
	lv.taken[BruteRagePerk.EAT] = 1
	lv.taken[BruteRagePerk.EAT_UP] = 1
	var heart := run.items.get_def(&"wolf_heart")
	t.check(BruteRagePerk.is_organ(heart) and not BruteRagePerk.is_organ(run.items.get_def(&"wolf_shank")), "狼心是器官，狼腿肉不是")
	t.eq(BruteRagePerk.eat_tip(run, run.items.get_def(&"bear_liver")), "战斗中每秒回复生命 +3，急速 -4%", "进食提示：好处在前、坏处在后")
	t.eq(BruteRagePerk.eat_tip(run, run.items.get_def(&"toad_leg")), "生命上限 +15", "肉的提示写生命上限")
	var hp0 := float(run.effective_baseline().base_stats.get(&"max_hp", 0.0))
	var st0 := float(run.effective_baseline().base_stats.get(&"max_stamina", 0.0))
	var rg0 := float(run.effective_baseline().base_stats.get(&"regen_hp", 0.0))
	for id in [&"wolf_heart", &"wolf_heart", &"viper_gall", &"bear_liver"]:
		var inst := ItemInstance.create(run.items.get_def(id))
		run.board.try_add(inst)
		var got := BruteRagePerk.eat(run, inst)
		t.check(got.has("trait") and float(got["hp"]) == 0.0, "%s：给特性、不加生命上限" % id)
	var tot := BruteRagePerk.organ_totals(run)
	t.check(is_equal_approx(float(tot.get(&"damage", 0.0)), 16.0) and is_equal_approx(float(tot.get(&"taken", 0.0)), 8.0), "两颗狼心叠：伤害 +16%%、受到 +8%%（%s）" % str(tot))
	t.check(is_equal_approx(float(tot.get(&"haste", 0.0)), 4.0), "蛇胆 +8、熊肝 -4：急速 +4%")
	var base := run.effective_baseline().base_stats
	t.check(is_equal_approx(float(base.get(&"max_hp", 0.0)), hp0 - 20.0), "蛇胆：生命上限 -20")
	t.check(is_equal_approx(float(base.get(&"regen_hp", 0.0)), rg0 + 3.0), "熊肝：每秒回复 +3")
	t.check(is_equal_approx(float(base.get(&"max_stamina", 0.0)), st0), "器官不给升级的一半耐力")
	var inp := CompileInput.new()
	OrganTraits.apply(inp, run)
	var dmg := inp.mods.filter(func(m: StatModifier) -> bool: return m.stat == BattleStats.DAMAGE and m.mode == StatModifier.Mode.MULT)
	t.check(dmg.size() == 1 and is_equal_approx((dmg[0] as StatModifier).amount, 16.0), "编进战斗：造成的伤害 ×1.16")
	t.check(is_equal_approx(inp.taken_pct, 8.0), "编进战斗：受到的伤害 +8%")
	t.check(is_equal_approx(run.compile_player().taken_pct, 8.0), "玩家这一方带上受到的伤害")
	var row := CharacterCard.stat_row(run, &"max_hp")
	t.check(String(row.get("tip", "")).contains("造成的伤害 +16%"), "状态界面生命上限那一行写器官合计")
	t.check(String(row.get("tip", "")).find("造成的伤害") < String(row.get("tip", "")).find("受到的伤害"), "好处在前")
	var back := LevelModule.new()
	back.restore(lv.to_dict())
	t.eq(int((back.god_state.get(BruteRagePerk.ORGANS_KEY, {}) as Dictionary).get("wolf_heart", 0)), 2, "吃下的器官进存档")
	run.dispose()


static func run_glands_and_pot(t: TestCase) -> void:
	t.begin("395 第五节 · 腺体也是器官（带食材、血肉，原有用处不变）；器官下锅给特性、放几件叠几次、整局有效；火焰腺每次攻击 +3 火伤、毒腺 15% 施加中毒、受到的治疗 −10%")
	var db := ItemDatabase.new()
	db.load_dir()
	for id in [&"fire_gland", &"frost_gland", &"viper_gland"]:
		var d := db.get_def(id)
		t.check(d != null and d.has_tag(&"ingredient") and d.has_tag(BruteRagePerk.FLESH_TAG) and d.has_tag(&"reagent") and OrganTraits.is_organ(d), "%s 是器官，还是试剂" % id)
	t.eq(OrganTraits.line(db.get_def(&"viper_gland").eat_trait), "每次攻击施加 1 层中毒的几率 +15%，受到的治疗 -10%", "毒腺：好处在前")
	var pot: Array = []
	for id in [&"wolf_heart", &"wolf_heart", &"fire_gland", &"wolf_shank"]:
		pot.append(ItemInstance.create(db.get_def(id)))
	var meal := Canteen.meal_of(pot)
	var got: Dictionary = meal.get("traits", {})
	t.check(is_equal_approx(float(got.get("damage", 0.0)), 16.0) and is_equal_approx(float(got.get("fire_hit", 0.0)), 3.0), "两颗狼心 + 火焰腺下锅：特性叠起来（%s）" % str(got))
	t.check(is_equal_approx(float((meal["flat"] as Dictionary).get("max_stamina", 0.0)), 3.0), "狼腿肉照旧按肉类给耐力上限 +3，器官不给（%s）" % str(meal["flat"]))
	t.check(ItemTooltip.canteen_line(db.get_def(&"wolf_heart")).contains("造成的伤害 +8%，受到的伤害 +4%"), "配菜提示：器官写特性，好处在前")
	# 进一局：饱腹归零也不失效
	var run := G388._start(3951)
	var mm := MealModule.new()
	mm.meal = meal.duplicate(true)
	mm.satiety = 0
	run.modules[MealModule.ID] = mm
	var tot := OrganTraits.totals(run)
	t.check(is_equal_approx(float(tot.get(&"damage", 0.0)), 16.0), "饱腹 0 了，器官的特性还在（整局有效）")
	var inp := CompileInput.new()
	OrganTraits.apply_values(inp, {&"fire_hit": 3.0, &"poison_chance": 15.0, &"heal": -10.0, &"regen_stamina": -5.0})
	t.eq(inp.rules.size(), 2, "火伤、中毒各挂一条单位规则")
	t.check(is_equal_approx(inp.heal_pct, -10.0), "受到的治疗 −10%")
	t.check(inp.baseline_mods.any(func(m: StatModifier) -> bool: return m.stat == BattleStats.REGEN_STAMINA and m.mode == StatModifier.Mode.MULT and is_equal_approx(m.amount, -5.0)), "耐力回复 −5%")
	var rt := CombatantRuntime.new()
	rt.heal_pct = -10.0
	t.check(is_equal_approx(StatMath.to_float(rt.heal_kept()), 0.9), "每秒回复也按治疗 −10% 打折")
	run.dispose()
