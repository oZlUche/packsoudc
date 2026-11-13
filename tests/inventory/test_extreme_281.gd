## 281 §五：极端武器两条线（斩首巨刃 → 处刑巨刃 → 焰纹处刑巨刃；破城矛 → 龙骨破城矛 → 雷纹破城矛）
extends RefCounted

const LINES := [
	[&"decapitator_blade", &"execution_blade", &"flame_execution_blade"],
	[&"siege_spear", &"dragonbone_siege_spear", &"thunder_siege_spear"],
]


static func run_lines(t: TestCase) -> void:
	t.begin("281 · 极端武器：蓝 / 紫 / 橙各一把，标签 extreme，橙只能锻造（铁匠铺材料打造）；说明留空")
	var items := ItemDatabase.new()
	items.load_dir()
	var recipes := SmithRecipeDef.load_all()
	for line in LINES:
		for k in line.size():
			var def := items.get_def(line[k])
			t.check(def != null and def.rarity == k + 2 and def.tags.has(EnemyPlacer.EXTREME), "%s：%d 档、极端" % [line[k], k + 2])
			if def == null:
				continue
			t.eq(def.is_no_random_source(), k == 2, "%s：橙只能锻造" % line[k])
			t.eq(def.description, "", "%s：说明留空" % line[k])
			if k == 2:     # 改造 D：砧升级拆了，橙档走 forge_* 材料打造
				t.eq(recipes.filter(func(r: SmithRecipeDef) -> bool: return r.output == line[k]).size(), 1, "%s：铁匠铺能打" % line[k])


static func run_enemies_skip(t: TestCase) -> void:
	t.begin("281 · 敌人不带极端武器：哪一档、哪个流派都抽不到")
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	for eid in [&"brute", &"berserker", &"warden"]:
		var who := enemies.enemy(eid)
		if who == null:
			continue
		var got := EnemyPlacer.school_items(who.schools, items, -1, who)
		var bad := got.filter(func(id: StringName) -> bool: return items.get_def(id).tags.has(EnemyPlacer.EXTREME))
		t.eq(bad, [], "%s 不限档：没有极端武器" % eid)
