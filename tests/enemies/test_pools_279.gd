## 279 §四.4：新武器进敌人池不另登记 —— 按流派与身份标签抽，档位的稀有度上限卡住档次（台架定调后武器另压一档：档 0 白、档 1 绿、档 2 蓝；别的道具照旧）
extends RefCounted


static func run_tiers(t: TestCase) -> void:
	t.begin("279 台架定调 · 敌人池：武器档 0 只抽得到白的，档 1 起绿、档 2 起蓝；药膏这类照旧按原来的上限；三个池子一样")
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var brute := enemies.enemy(&"brute")
	t.check(pool != null and brute != null, "有标准废墟池和蛮兵")
	if pool == null or brute == null:
		return
	for pid in ["standard_ruins", "clockwork", "hunters"]:
		var p := ContentPaths.load_asset("enemy_pools", pid) as EnemyPool
		var caps := [0, 1, 2].map(func(k: int) -> int: return EnemyPlacer.rarity_cap_of(p.loadout, p.tiers[k]))
		var wcaps := [0, 1, 2].map(func(k: int) -> int: return EnemyPlacer.weapon_cap_of(p.loadout, p.tiers[k]))
		t.eq([caps, wcaps], [[1, 2, -1], [0, 1, 2]], "%s：武器档 0 白、档 1 绿、档 2 蓝；别的照旧绿 / 蓝 / 不限" % pid)
	var cap0 := EnemyPlacer.rarity_cap_of(pool.loadout, pool.tiers[0])
	var cap1 := EnemyPlacer.rarity_cap_of(pool.loadout, pool.tiers[1])
	var cap2 := EnemyPlacer.rarity_cap_of(pool.loadout, pool.tiers[2])
	var tier0 := EnemyPlacer.school_items(brute.schools, items, cap0, brute, EnemyPlacer.weapon_cap_of(pool.loadout, pool.tiers[0]))
	var tier1 := EnemyPlacer.school_items(brute.schools, items, cap1, brute, EnemyPlacer.weapon_cap_of(pool.loadout, pool.tiers[1]))
	var tier2 := EnemyPlacer.school_items(brute.schools, items, cap2, brute, EnemyPlacer.weapon_cap_of(pool.loadout, pool.tiers[2]))
	var common0 := EnemyPlacer.common_items(brute.schools, pool.loadout, items, cap0, brute, EnemyPlacer.weapon_cap_of(pool.loadout, pool.tiers[0]))
	t.check(common0.has(&"salve"), "档 0：绿的药膏照样抽得到（只压武器）")
	t.check(tier0.has(&"club") and not tier0.has(&"broadsword"), "档 0：棍棒（白）有，阔剑（绿）没有")
	t.check(tier1.has(&"broadsword") and tier1.has(&"great_axe") and not tier1.has(&"bone_broadsword"), "档 1：阔剑 / 大斧（绿）进来，蓝件没有")
	t.check(tier2.has(&"bone_broadsword") and tier2.has(&"steel_greatsword") and not tier2.has(&"bonesteel_greatsword"), "档 2：蓝件进来，紫件没有")
	var archer := EnemyPlacer.school_items(enemies.enemy(&"marksman").schools, items, cap1, enemies.enemy(&"marksman"), EnemyPlacer.weapon_cap_of(pool.loadout, pool.tiers[1]))
	t.check(archer.has(&"crude_bow") and archer.has(&"light_crossbow") and not archer.has(&"broadsword"), "神射手只背弓弩：粗制弓 / 轻弩有，阔剑没有")
