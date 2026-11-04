## 279 §四.4：新武器进敌人池不另登记 —— 按流派与身份标签抽，档位的稀有度上限把档 0 卡在绿、档 1 卡在蓝
extends RefCounted


static func run_tiers(t: TestCase) -> void:
	t.begin("279 · 敌人池：档 0 的蛮兵抽得到白绿新件、抽不到蓝件；档 1 起蓝件进来")
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var brute := enemies.enemy(&"brute")
	t.check(pool != null and brute != null, "有标准废墟池和蛮兵")
	if pool == null or brute == null:
		return
	var cap0 := EnemyPlacer.rarity_cap_of(pool.loadout, pool.tiers[0])
	var cap1 := EnemyPlacer.rarity_cap_of(pool.loadout, pool.tiers[1])
	t.eq([cap0, cap1], [1, 2], "档 0 上限绿、档 1 上限蓝")
	var tier0 := EnemyPlacer.school_items(brute.schools, items, cap0, brute)
	var tier1 := EnemyPlacer.school_items(brute.schools, items, cap1, brute)
	t.check(tier0.has(&"club") and tier0.has(&"broadsword") and tier0.has(&"great_axe"), "档 0：棍棒（白）、阔剑 / 大斧（绿）")
	t.check(not tier0.has(&"bone_broadsword") and not tier0.has(&"steel_greatsword"), "档 0：没有蓝件")
	t.check(tier1.has(&"bone_broadsword") and tier1.has(&"steel_greatsword"), "档 1：蓝件进来")
	var archer := EnemyPlacer.school_items(enemies.enemy(&"marksman").schools, items, cap0, enemies.enemy(&"marksman"))
	t.check(archer.has(&"crude_bow") and not archer.has(&"broadsword"), "神射手只背弓弩：粗制弓有，阔剑没有")
