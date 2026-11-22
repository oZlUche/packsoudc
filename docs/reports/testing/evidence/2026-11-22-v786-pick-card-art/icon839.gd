extends SceneTree
func _initialize() -> void:
	var rules := LevelRules.load_rules()
	var no := []
	var yes := []
	for id in rules.card_ids():
		var p := "res://data/run_buffs/%s.tres" % String(id)
		var d: RunBuffDef = load(p) if ResourceLoader.exists(p) else null
		var t := LevelPickPanel._icon_of_def(d)
		var stats := []
		if d != null:
			for e in d.effects: stats.append(String(e.stat) if e is StatBonus else e.get_class())
		(yes if t != null else no).append("%s[%s]%s" % [String(id), String(rules.kind_of(id)), str(stats)])
	print("ICON 有图标 %d：%s" % [yes.size(), str(yes)])
	print("ICON 空圆章 %d：%s" % [no.size(), str(no)])
	quit(0)
