## 394（作者 11-25）：【血肉】只是子类标签（素材 → 食材 → 血肉），三件占位换成按野兽分的肉和器官；
## 每种魔兽必掉自己的肉、器官按几率掉；都能下食堂的锅（肉类）；老存档的占位换成蟾腿 / 鳗段 / 熊掌
extends RefCounted

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
	t.begin("394 · 掉落：每种魔兽必掉自己的肉；器官 30%（狼心、蛇胆、熊肝），几十场里有掉有不掉")
	var c := TestSupport.load_content("free_mode")
	for e in BEASTS:
		var def := c.enemies.enemy(e)
		if def == null:
			t.check(false, "有 %s" % e)
			continue
		var meat: StringName = BEASTS[e][0]
		var organ: StringName = BEASTS[e][1]
		t.eq(def.loot_bonus, [meat] as Array[StringName], "%s 必掉 %s" % [e, meat])
		if organ != &"":
			t.check(is_equal_approx(float(def.loot_chance.get(organ, 0.0)), 0.3), "%s 的 %s 30%%" % [e, organ])
		else:
			t.check(def.loot_chance.is_empty(), "%s 没有器官" % e)
	for e in [&"flame_wolf", &"pit_viper", &"cave_bear"]:
		var def := c.enemies.enemy(e)
		var hit := 0
		var meat_all := true
		for i in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = 394 * 100 + i
			var items: Array = EnemyPlacer.build_content(def, c.pool, c.items, def.strength, rng)["content"]["items"]
			var ids: Array = items.filter(func(x: Dictionary) -> bool: return bool(x.get("carried", false))).map(func(x: Dictionary) -> String: return String(x["id"]))
			meat_all = meat_all and ids.has(String(BEASTS[e][0]))
			if ids.has(String(BEASTS[e][1])):
				hit += 1
		t.check(meat_all, "%s 40 场都掉肉" % e)
		t.check(hit > 3 and hit < 25, "%s 器官 40 场掉了 %d 次" % [e, hit])
