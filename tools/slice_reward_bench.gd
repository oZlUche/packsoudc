## 切片 v6.14 D01：盾卫奖励候选对打。按路线推出到盾卫 / 守卫时手上的东西（合成按玩家会做的合），各打 N 个种子
extends SceneTree


func _init() -> void:
	var seeds := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.trim_prefix("--seeds="))
	var items := ItemDatabase.new()
	items.load_dir()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var ch := ContentPaths.load_asset("characters", "andreus") as CharacterDef
	var fights := SliceBench.fights_of("res://data/maps/slice_ruins.json")
	var foes := {}
	for f in fights:
		foes[int(f["node"])] = EnemyKit.spec_of(f["content"], enemies, null, items)
	var kits := {
		"强攻 · 到盾卫": ["quenched_dagger", "knife", "leather_armor", "salve", "bandage_roll", "ration", "whetstone"],
		"坚守 · 到盾卫": ["quenched_dagger", "leather_armor", "leather_armor", "salve", "bandage_roll", "ration", "whetstone"],
		"强攻 · 绕行到守卫": ["quenched_dagger", "poisoned_knife", "round_shield", "leather_armor", "salve", "bandage_roll", "ration"],
		"坚守 · 绕行到守卫": ["poisoned_knife", "round_shield", "leather_armor", "leather_armor", "salve", "bandage_roll", "whetstone"],
		"强攻 · 绕行无圆盾（候选 1）": ["quenched_dagger", "poisoned_knife", "leather_armor", "salve", "bandage_roll", "ration"],
		"坚守 · 绕行无圆盾（候选 1）": ["poisoned_knife", "leather_armor", "leather_armor", "salve", "bandage_roll", "whetstone"],
		"强攻 · 正面 + 必掉匕首（候选 2）": ["quenched_dagger", "poisoned_knife", "twin_blades", "round_shield", "leather_armor", "salve", "bandage_roll"],
		"坚守 · 正面 + 必掉匕首（候选 2）": ["poisoned_knife", "quenched_dagger", "round_shield", "leather_armor", "leather_armor", "salve", "bandage_roll"],
		"强攻 · 正面 + 必掉弯刀（候选 3）": ["quenched_dagger", "poisoned_knife", "scimitar", "round_shield", "leather_armor", "salve", "bandage_roll"],
		"坚守 · 正面 + 必掉弯刀（候选 3）": ["poisoned_knife", "scimitar", "round_shield", "leather_armor", "leather_armor", "salve", "bandage_roll"],
		"强攻 · 正面 + 必掉剁刀（候选 4）": ["quenched_dagger", "poisoned_knife", "cleaver", "round_shield", "leather_armor", "salve", "bandage_roll"],
		"坚守 · 正面 + 必掉剁刀（候选 4）": ["poisoned_knife", "cleaver", "round_shield", "leather_armor", "leather_armor", "salve", "bandage_roll"],
	}
	kits["强攻 · 无毒（淬火 + 匕首 + 圆盾 + 皮甲）"] = ["quenched_dagger", "knife", "round_shield", "leather_armor", "salve", "bandage_roll", "ration"]
	kits["坚守 · 无毒（淬火 + 圆盾 + 两件皮甲）"] = ["quenched_dagger", "round_shield", "leather_armor", "leather_armor", "salve", "bandage_roll"]
	kits["只有毒匕首 + 补给"] = ["poisoned_knife", "bandage", "ration"]
	kits["无毒 + 弯刀"] = ["quenched_dagger", "scimitar", "round_shield", "leather_armor", "salve"]
	kits["无毒 + 剁刀"] = ["quenched_dagger", "cleaver", "round_shield", "leather_armor", "salve"]
	var md := "| 手上的东西 | 盾卫 | 守卫 |\n|---|---|---|\n"
	for k in kits:
		var me := SliceBench.player(ch, items, kits[k])
		var cells: Array[String] = []
		for nid in [6, 11]:
			var x := SliceBench.cell(me, foes[nid], seeds)
			cells.append("%d%%（剩 %d%%）" % [roundi(x["win"] * 100.0), roundi(x["hp"] * 100.0)])
		md += "| %s | %s |\n" % [k, " | ".join(cells)]
	print(md)
	var eco := ContentPaths.load_asset("economy_rules", "slice_ruins") as EconomyRules
	for id in ["poison_vial", "round_shield", "leather_armor", "whetstone", "shortsword", "linen_bolt", "scimitar", "cleaver", "knife", "bag_leather"]:
		var d := items.get_def(StringName(id))
		print("%s 买 %d 卖 %d" % [id, ShopSession.price_for(d, eco), maxi(1, roundi(float(ItemValue.of(d)) * eco.shop_sell_ratio))])
	quit()
