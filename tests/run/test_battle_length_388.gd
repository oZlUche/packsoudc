## 388 第二节（战斗拉到 10~20 秒）：基础生命、耐力放大以后的数据护栏，和老档里写死的敌人数值按同样倍数换算
extends RefCounted


static func run_data(t: TestCase) -> void:
	t.begin("388 · 数据：三位角色的基础生命、耐力按新数")
	var want := {&"andreus": [160, 110, 8], &"marcus": [195, 130, 10], &"brutus": [300, 130, 8]}
	for id in want:
		var c := ContentPaths.load_asset("characters", String(id)) as CharacterDef
		t.not_null(c, "%s 在" % id)
		if c == null:
			continue
		var b := c.baseline()
		t.eq([int(b.value_of(&"max_hp", 0.0)), int(b.value_of(&"max_stamina", 0.0)), int(b.value_of(&"regen_stamina", 0.0))],
			want[id], "%s 生命 / 耐力 / 回复" % id)
	t.eq([CombatantBaseline.DEFAULT_STATS["max_stamina"], CombatantBaseline.DEFAULT_STATS["regen_stamina"]], [100.0, 8.0], "默认耐力 ×2")


static func run_legacy_save(t: TestCase) -> void:
	t.begin("388 · 老档：写死的敌人生命 ×3.5（取整到 5）、耐力 ×2；没写的不动；新档带标记")
	var c := {"enemy": "raider", "base_stats": {"max_hp": 20, "max_stamina": 60.0, "regen_stamina": 8.0, "block": 2}}
	RunState.rescale_content(c)
	t.eq(c["base_stats"], {"max_hp": 70.0, "max_stamina": 120.0, "regen_stamina": 16.0, "block": 2}, "20 → 70，耐力翻倍，格挡不动")
	var plain := {"enemy": "raider"}
	RunState.rescale_content(plain)
	t.eq(plain, {"enemy": "raider"}, "没有写死数值的点不动")
	t.eq(RunState.BATTLE_SCALE, 388, "新档写的标记")
