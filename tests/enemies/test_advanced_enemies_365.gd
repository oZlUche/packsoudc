## Report 365 (author 2026-11-21 17:22 / 17:24 / 17:33): advanced enemies batch 1, rank by difficulty level
extends RefCounted


static func run_rank(t: TestCase) -> void:
	t.begin("365: portrait metal follows the difficulty level")
	t.check(EnemyRank.metal(0, &"battle") == EnemyRank.BRONZE, "A0 normal = bronze")
	t.check(EnemyRank.metal(1, &"battle") == EnemyRank.SILVER, "A1 normal = silver")
	t.check(EnemyRank.metal(3, &"battle") == EnemyRank.SILVER, "A3 normal = silver")
	t.check(EnemyRank.metal(4, &"battle") == EnemyRank.GOLD, "A4 normal = gold")
	t.check(EnemyRank.metal(0, &"elite") == EnemyRank.SILVER, "A0 elite = silver")
	t.check(EnemyRank.metal(3, &"elite") == EnemyRank.SILVER, "A3 elite = silver")
	t.check(EnemyRank.metal(4, &"elite") == EnemyRank.GOLD, "A4 elite = gold")
	t.check(EnemyRank.metal(0, &"core") == EnemyRank.GOLD, "boss = gold")
	t.check(EnemyRank.metal(0, &"elite", true) == EnemyRank.GOLD, "guard = gold")


static func run_prefix(t: TestCase) -> void:
	t.begin("365: beasts get an age prefix, humans and constructs do not")
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var lizard := enemies.enemy(&"molten_lizard")
	t.check(lizard != null, "molten_lizard exists")
	if lizard != null:
		t.check(EnemyRank.display_name(lizard, EnemyRank.BRONZE) == UiText.t("enemy.rank_prefix.bronze") + Names.of(lizard), "bronze beast prefix")
		t.check(EnemyRank.display_name(lizard, EnemyRank.GOLD) == UiText.t("enemy.rank_prefix.gold") + Names.of(lizard), "gold beast prefix")
	for id in [&"centurion", &"arc_coil", &"warden"]:
		var def := enemies.enemy(id)
		t.check(def != null and EnemyRank.display_name(def, EnemyRank.GOLD) == Names.of(def), "%s has no prefix" % id)


static func run_roster(t: TestCase) -> void:
	t.begin("365: batch 1 roster sits in the pools; warden renamed")
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var ruins := ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var clock := ContentPaths.load_asset("enemy_pools", "clockwork") as EnemyPool
	var in_ruins := {}
	for e in ruins.entries:
		in_ruins[e.enemy] = e
	var in_clock := {}
	for e in clock.entries:
		in_clock[e.enemy] = e
	for id in [&"molten_lizard", &"frost_mane", &"thunder_vulture", &"miasma_spider", &"tusk_boar", &"centurion"]:
		t.check(in_ruins.has(id), "%s in standard_ruins" % id)
	for id in [&"condenser_automaton", &"arc_coil"]:
		t.check(in_clock.has(id), "%s in clockwork" % id)
	if in_ruins.has(&"centurion"):
		t.check((in_ruins[&"centurion"] as EnemyPoolEntry).node_types.size() == 1 and (in_ruins[&"centurion"] as EnemyPoolEntry).node_types[0] == &"elite", "centurion only at elite nodes")
	t.check(enemies.enemy(&"warden").display_name == "看守", "warden is now 看守")


static func run_gold_signature(t: TestCase) -> void:
	t.begin("365: gold rank beasts (A4+) carry their legendary material")
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var items := ItemDatabase.new()
	items.load_dir()
	var pool := ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var pairs := {&"molten_lizard": &"undying_ember", &"frost_mane": &"frigid_tear", &"thunder_vulture": &"thunder_marrow",
		&"miasma_spider": &"miasma_source", &"cave_bear": &"unclotting_blood"}
	for id in pairs:
		var def := enemies.enemy(id)
		t.check(def != null and def.gold_signature.has(pairs[id]), "%s gold signature" % id)
		if def == null:
			continue
		for strength in [2, 3]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7 + strength
			var with_gold: Dictionary = EnemyPlacer.build_content(def, pool, items, strength, rng, null, null, {}, def.gold_signature).get("content", {})
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 7 + strength
			var plain: Dictionary = EnemyPlacer.build_content(def, pool, items, strength, rng2).get("content", {})
			t.check(_has(with_gold, pairs[id]), "%s tier %d carries %s at gold" % [id, strength, pairs[id]])
			if strength < 3:     # tier 3 random fills may roll a legendary on their own
				t.check(not _has(plain, pairs[id]), "%s tier %d does not carry it below gold" % [id, strength])


static func _has(content: Dictionary, item: StringName) -> bool:
	for raw in content.get("items", []):
		if StringName(String((raw as Dictionary).get("id", ""))) == item:
			return true
	return false
