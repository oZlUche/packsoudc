extends SceneTree
## 真游戏开局（新档、拒教程、begin_direct 常规章）逐个种子看「无名的祭坛」靠近后到哪位神
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _s := 1
var cnt := {}
func _initialize() -> void:
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
func _ch() -> ChapterDef:
	for c in _flow.available_chapters():
		if not (c as ChapterDef).id.begins_with("prologue"): return c
	return null
func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f < 60: return false
	match _st:
		0: _flow.start_new_game(); _st = 1; return false
		1:
			if _f < 200: return false
			_flow.decline_tutorial(); _st = 2; return false
		2:
			if _f < 260: return false
			var ch := _ch()
			if _s == 1: print("AG 章 %s" % String(ch.id))
			var r := _flow.begin_direct(ch, _s)
			var g := "无祭坛"
			for id in r.map.node_ids():
				var nd := r.map.get_node(id)
				if String(nd.content.get("event", "")) == "faith_call":
					var near := (r.events.def_by_id(&"faith_call").options[0] as EventOption)
					for o in near.outcomes:
						if o is NextEventRandom:
							var ctx := r.events._event_ctx(nd)
							(o as NextEventRandom).apply(ctx)
							g = "%s（点 %d，content_seed %d）" % [String(ctx.next_event), id, nd.content_seed]
			cnt[g.get_slice("（", 0)] = int(cnt.get(g.get_slice("（", 0), 0)) + 1
			print("AG 种子 %d：%s" % [_s, g])
			_flow.to_main_menu()
			_s += 1
			if _s > 40:
				print("AG 分布 %s" % str(cnt)); quit(0); return true
			_st = 3
		3:
			_flow.continue_game(); _st = 2; _f = 250
	return false
