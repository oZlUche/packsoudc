## 报告 303 · 难度候选实验（材料与难度方案 §7.2 D1 / D3）：改数只动实验副本、只动点名的敌人；逐场配对按 case_id 对齐
extends RefCounted


static func run_foe_mutation(t: TestCase) -> void:
	t.begin("303 · 难度实验改数：brute 的生命 / 格挡按自己的基线乘，别的敌人、原内容、档位表都不动；双方生命同乘")
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var pool := ContentPaths.load_asset("enemy_pools", "standard_ruins") as EnemyPool
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var content: Dictionary = EnemyPlacer.build_content(enemies.enemy(&"brute"), pool, items, 3, rng).get("content", {})
	t.check(not content.is_empty(), "造得出档 3 的 brute")
	var before := content.duplicate(true)
	var tier := pool.tier_of(3)
	var scale_before := tier.stat_scale.duplicate()
	var m := {"foe": {"brute": {"max_hp": 0.9}}}
	var got := BalanceMutation.foe_content(content, m, enemies, pool)
	t.eq(content, before, "原内容不动")
	t.eq(tier.stat_scale, scale_before, "档位表不动")
	var b0 := EnemyKit.baseline_of(enemies.enemy(&"brute"), tier, content)
	var b1 := EnemyKit.baseline_of(enemies.enemy(&"brute"), tier, got)
	t.check(absf(b1.value_of(&"max_hp", 0.0) - b0.value_of(&"max_hp", 0.0) * 0.9) < 0.001, "基础生命 ×0.9（档位倍率之后再乘）")
	t.check(absf(b1.value_of(&"block", 0.0) - b0.value_of(&"block", 0.0)) < 0.001, "格挡没改")
	var s0 := EnemyKit.spec_of(content, enemies, pool, items)
	var s1 := EnemyKit.spec_of(got, enemies, pool, items)
	t.check(s1.max_hp < s0.max_hp, "编译出来的生命也少了")
	var other: Dictionary = EnemyPlacer.build_content(enemies.enemy(&"raider"), pool, items, 3, rng).get("content", {})
	t.eq(BalanceMutation.foe_content(other, m, enemies, pool), other, "别的敌人不动")
	var hp := s0.max_hp
	BalanceMutation.scale_hp(s0, {"hp": 1.3})
	t.eq(s0.max_hp, roundi(hp * 1.3), "双方生命同乘")
	BalanceMutation.scale_hp(s0, {})
	t.eq(s0.max_hp, roundi(hp * 1.3), "空改数 = 不改")


static func run_pairing(t: TestCase) -> void:
	t.begin("303 · 难度候选表：按 case_id 配对，按（段, 档）分格；无效场不算进差值")
	var base := [
		{"case_id": "c1", "bracket": 1, "tier": 1, "archetype": "shield", "valid": true, "outcome": BattleMetrics.WIN, "duration": 4.0},
		{"case_id": "c2", "bracket": 1, "tier": 1, "archetype": "shield", "valid": true, "outcome": BattleMetrics.LOSS, "duration": 3.0},
		{"case_id": "c3", "bracket": 1, "tier": 1, "archetype": "burst", "valid": false, "outcome": "", "duration": null},
	]
	var var_ := [
		{"case_id": "c1", "bracket": 1, "tier": 1, "archetype": "shield", "valid": true, "outcome": BattleMetrics.WIN, "duration": 5.0},
		{"case_id": "c2", "bracket": 1, "tier": 1, "archetype": "shield", "valid": true, "outcome": BattleMetrics.WIN, "duration": 4.0},
		{"case_id": "c3", "bracket": 1, "tier": 1, "archetype": "burst", "valid": true, "outcome": BattleMetrics.WIN, "duration": 2.0},
	]
	var rows := DifficultyCandidates.compare(base, var_)
	t.eq(rows.size(), 1, "一格")
	var r: Dictionary = rows[0]
	t.eq(int(r["win_diff"]["n"]), 2, "基线无效的那场不配对")
	t.check(absf(float(r["win_diff"]["diff"]) - (0.5)) < 0.0001, "胜率差 +50 个百分点")
	t.check(absf(float(r["dur_diff"]["diff"]) - (1.0)) < 0.0001, "时长差 +1 秒")
	t.eq(DifficultyCandidates.compare(base, var_, true).size(), 2, "按流派分两格")
