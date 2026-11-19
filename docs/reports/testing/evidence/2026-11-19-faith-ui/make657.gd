extends SceneTree
## 在 v6.56（没有委托）上做旧档：新游戏 → 拒教程 → 直开常规章 → 撤离结算一局（局外档落地）→ 再开一局走到地图存档退出。
## 参数：<快照输出目录>。把结算后的局外档 to_dict 写到 <目录>/meta_before.json
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func _chapter() -> ChapterDef:
	for c in _flow.available_chapters():
		if not (c as ChapterDef).id.begins_with("prologue"): return c
	return null


func _to_map() -> bool:
	if _flow.screen == GameFlow.Screen.EVENT:
		if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
		elif _flow.run.events.pending_event() != null: _flow.choose_event(0)
		_wait = 10
		return false
	if _flow.screen != GameFlow.Screen.MAP: return false
	if _flow.run.phase == RunState.Phase.PICK_SPAWN:
		_flow.pick_spawn(_flow.run.map.entry_ids[0]); _wait = 10
		return false
	return true


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 5000:
		print("OLD 超时 st %d 屏 %s" % [_st, GameFlow.Screen.keys()[_flow.screen]]); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open(): b.decline_tutorial()
			elif _f > 240: _flow.decline_tutorial()
			else: return false
			_wait = 20; _st = 2
		2:
			var ch := _chapter()
			print("OLD 版本 %s；开 %s" % [str(MetaState.SAVE_VERSION), String(ch.id) if ch else "无"])
			if ch == null: quit(1); return true
			_flow.begin_direct(ch, 424242); _st = 3
		3:
			if not _to_map(): return false
			print("OLD 第一局撤离 %s" % str(_flow.run.force_extract()))
			_flow._flush(); _wait = 60; _st = 4
		4:
			print("OLD 结算后屏 %s；局外档 %s" % [GameFlow.Screen.keys()[_flow.screen], _flow.meta_path])
			var d = JSON.parse_string(FileAccess.get_file_as_string(_flow.meta_path))
			print("OLD 局外档 version %s，有 commissions 键 %s，键数 %d" % [str(d.get("version")), str(d.has("commissions")), d.size()])
			var fa := FileAccess.open(_out + "/meta_before.json", FileAccess.WRITE)
			fa.store_string(JSON.stringify(d, "\t", true)); fa.close()
			_flow.to_main_menu(); _wait = 30; _st = 5
		5:
			_flow.continue_game(); _wait = 30; _st = 6
		6:
			# 基地 → 再开一局
			var ch := _chapter()
			_flow.begin_direct(ch, 525252); _st = 7
		7:
			if not _to_map(): return false
			print("OLD 第二局存档 %s → %s" % [str(_flow.save()), _flow.save_path])
			_flow.save_meta()
			var d2 = JSON.parse_string(FileAccess.get_file_as_string(_flow.meta_path))
			d2.erase("content_stamp")
			var fb := FileAccess.open(_out + "/meta_before.json", FileAccess.WRITE)
			fb.store_string(JSON.stringify(d2, "\t", true)); fb.close()
			print("OLD 第二局开局后的局外档另存为对照（键数 %d）" % d2.size())
			quit(0); return true
	return false
