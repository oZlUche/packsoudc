extends SceneTree
## 测试 v9.37（PR #1017）无头：铆钉挎包里整件放着的每件 +5 护甲；悬浮窗「包里每件东西」；max_armor 显示名「护甲 / Armor」
const G := preload("res://tests/run/test_god_cards_388.gd")


func _armor(bag: StringName, items: Array) -> Array:
	var run := G._start(5, &"brute")
	var olds := run.board.items().duplicate()
	for it in olds: run.board.remove(it.uid)
	var b := TestSupport.put(run.board, run.items.get_def(bag))
	var n := 0
	for id in items:
		var bu := b.uid
		var brd := run.board
		if TestSupport.put_where(run.board, run.items.get_def(StringName(id)), func(i: ItemInstance) -> bool:
			for c in i.cells():
				if brd.bag_at(c) != bu: return false
			return true) != null: n += 1
	var me := run.compile_player()
	var rt := CombatantRuntime.from_spec(me, 0)
	var a := StatMath.to_float(rt.resources.maximum(BattleStats.RES_ARMOR)) if rt.resources.has(BattleStats.RES_ARMOR) else 0.0
	var tip := ""
	if bag == &"studded_satchel":
		for lang in ["zh", "en"]:
			UiText.lang = lang
			var full := ItemTooltip.describe_full(b, run.board)
			tip += " | %s：%s" % [lang, str(full.get("text", full)).replace("\n", " / ").left(260)]
		UiText.lang = "zh"
	run.dispose()
	return [a, n, tip]


func _init() -> void:
	for set in [["空包", []], ["1 件绷带", ["bandage"]], ["4 件绷带", ["bandage", "bandage", "bandage", "bandage"]], ["2 把小刀（1×2）", ["knife", "knife"]]]:
		var s := _armor(&"studded_satchel", set[1])
		var p := _armor(&"bag_leather", set[1])
		print("SS1017 %s：铆钉挎包护甲 %.0f（放进 %d 件），皮包 %.0f；差 %.0f%s" % [set[0], s[0], s[1], p[0], s[0] - p[0], s[2] if set[0] == "4 件绷带" else ""])
	for lang in ["zh", "en"]:
		UiText.lang = lang
		print("SS1017 max_armor 显示名 %s：%s" % [lang, Glossary.stat_name(&"max_armor")])
	print("SS1017 完")
	quit(0)
