extends SceneTree
## 测试 v9.17（PR #990）无头：怒意延绵英文名、众星牌面；顺带查所有神的牌有没有重名
const G := preload("res://tests/run/test_god_cards_388.gd")
func _init() -> void:
	var run := G._start(5, &"sun")
	var lv := LevelModule.of(run)
	for lang in ["zh", "en"]:
		UiText.lang = lang
		for c in ["god_brute_linger", "god_brute_persist", "god_sun_stars"]:
			var d := lv.card_def(StringName(c))
			var name := d.display_name if lang == "zh" else String(d.display_names.get("en", "?"))
			print("TX990 %s %s【%s】%s" % [lang, c, name, lv.card_text(StringName(c))])
	UiText.lang = "zh"
	var seen := {"zh": {}, "en": {}}
	var n := 0
	for k in lv.rules().cards:
		var d := lv.card_def(StringName(k))
		if d == null: continue
		n += 1
		var zh := d.display_name.replace("（升级）", "")
		var en := String(d.display_names.get("en", "")).trim_suffix("+").to_lower().replace("ou", "o")
		for pair in [["zh", zh], ["en", en]]:
			var m: Dictionary = seen[pair[0]]
			var base := String(k).trim_suffix("_up")
			if m.has(pair[1]) and m[pair[1]] != base: print("TX990 重名 %s「%s」：%s / %s" % [pair[0], pair[1], m[pair[1]], base])
			m[pair[1]] = base
	print("TX990 查了 %d 张牌的名字（英文忽略大小写、ou/o 拼法）" % n)
	run.dispose()
	quit(0)
