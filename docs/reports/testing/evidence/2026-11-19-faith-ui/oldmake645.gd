extends SceneTree
## 在 v6.44（旧规则：最后置入的信物 = 信仰）上做一局真存档：开场一问【不需要】→ 直开常规图 → 棋盘先放蛮神、再放日神 → 存档退出。
## 参数：<章 id，可空>。切片用 --profile=slice 跑（存档进 user://slice/）
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _want := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _want = a[0]
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 4000:
		print("OLD 超时"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game()
			_st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial()
				_wait = 20
				_st = 2
			elif _f > 240:
				print("开场一问没弹（屏 %s，章 %s）：直接 decline_tutorial" % [GameFlow.Screen.keys()[_flow.screen], String(_flow.run.chapter.id) if _flow.run != null else "无"])
				_flow.decline_tutorial()
				_wait = 20
				_st = 2
		2:
			var ch: ChapterDef = null
			for c in _flow.available_chapters():
				if not (c as ChapterDef).id.begins_with("prologue") and (_want == "" or String((c as ChapterDef).id) == _want): ch = c; break
			print("OLD 档案 %s；可出 %s → %s" % [String(_flow.profile), str(_flow.available_chapters().map(func(c): return String(c.id))), String(ch.id) if ch != null else "无"])
			if ch == null: quit(1); return true
			_flow.begin_direct(ch, 424242)
			_st = 3
		3:
			if _flow.screen == GameFlow.Screen.EVENT:
				if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
				elif _flow.run.events.pending_event() != null: _flow.choose_event(0)
				_wait = 10
				return false
			if _flow.screen != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				print("OLD 挑出生点 %d：%s" % [_flow.run.map.entry_ids[0], str(_flow.pick_spawn(_flow.run.map.entry_ids[0]))])
				_wait = 10
				return false
			var r := _flow.run
			for id in [&"charm_brute", &"charm_sun"]:
				r.board.try_add(ItemInstance.create(_flow.items.get_def(id), 0))
				_flow._flush()
			if r.has_method("select_faith"):
				var why: String = r.select_faith(&"brute")
				r.faith_power.add_points(&"brute", 140)
				print("OLD（v6.45）奉蛮神「%s」，给 140 信力 → 有效 %s，信力 %d" % [why, String(r.active_faith_id()), r.faith_power.points_of(&"brute")])
			else:
				r.faith_power.add_points(r.active_faith_id(), 60)
				print("OLD（v6.44）放了蛮神再放日神：激活 %s，给它 60 信力 → %d" % [String(r.active_faith_id()), r.faith_power.points_of(r.active_faith_id())])
			_flow._flush()
			print("OLD 存档 %s → %s" % [str(_flow.save()), _flow.save_path])
			var d = JSON.parse_string(FileAccess.get_file_as_string(_flow.save_path))
			print("OLD 存档 version %s" % str(d.get("version")))
			quit(0)
			return true
	return false
