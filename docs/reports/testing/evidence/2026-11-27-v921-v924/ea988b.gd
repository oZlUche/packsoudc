extends SceneTree
## 测试 v9.21 补充：穿行落到战斗 / 精英 / 事件点后，那个点的事发生了没有、扎营能不能用
const G := preload("res://tests/run/test_god_cards_388.gd")
func _init() -> void:
	for s in [800, 801, 803]:
		var run := G._start(s, &"earth")
		var belt := BeltModule.of(run)
		belt.add(&"earth_walk", 1); belt.add(&"earth_camp", 1)
		var here := run.travel.current_id
		belt.use(&"earth_walk")
		var targets: Array[int] = EarthHeavenPerk.walk_targets(run)
		var within2: Dictionary = MapNavigator.within_steps(run.map, here, 2)
		var far := -1
		for id in targets:
			if not within2.has(id): far = id
		EarthHeavenPerk.walk_to(run, far)
		var node := run.current_node()
		print("EA988B 种子 %d：传到 %s，visited %s，pending_battle %s，pending_event %s，phase %s，last_handled %d，结束 %s" % [s, NodeEvents.effective_type(node), str(node.is_visited()), str(run.events.pending_battle), str(run.events.pending_event()), str(run.phase), run.events.last_handled_id, str(run.is_over())])
		print("EA988B   扎营：", belt.can_use(&"earth_camp"))
		run.dispose()
	quit(0)
