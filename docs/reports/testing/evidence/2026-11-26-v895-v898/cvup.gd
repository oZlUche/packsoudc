extends SceneTree
## v8.96：改信时升级版质变也还一次重选（无头）
const G := preload("res://tests/run/test_god_cards_388.gd")
func _init() -> void:
	var run := G._start(3, &"skill")
	var lv := LevelModule.of(run)
	var r := lv.rules()
	print("CVUP god_skill_gap 质变 %s；god_skill_gap_up 质变 %s 升级自 %s" % [str(r.is_qual(&"god_skill_gap")), str(r.is_qual(&"god_skill_gap_up")), str(r.card(&"god_skill_gap_up").get("upgrade_of", ""))])
	lv.taken = {"god_skill_gap": 1, "god_skill_gap_up": 1, "god_skill_stream": 2, "god_skill_cloud": 2, "god_skill_parry": 1}
	lv.convert_faith(&"skill", &"sun")
	print("CVUP 拿了 质变 1 + 升级版 1 + 基础 5 张，改信以后 god_state %s；repicks_left %d；剩下的牌 %s" % [str(lv.god_state), lv.repicks_left(), str(lv.taken)])
	run.dispose()
	quit(0)
