extends SceneTree
## v6.44 复现：教程二地图上 Esc → 跳过剩余教程 → 【接着学】之后地图自己走了一步？
## trial 1 真点（press+release 同帧）；trial 2 直接发 pressed 信号；trial 3 真点但 press / release 分两帧
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _trial := 1
var _wait := 0
var _node0 := -1
var out := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_flow = _game.flow


func L(s: String) -> void:
	print("R644 " + s)


func shot(n: String) -> void:
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%s.png" % [out, n])


func _btn(text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).is_visible_in_tree() and (n as Button).text.strip_edges() == text: return n
	return null


func _mouse(b: Control, down: bool) -> void:
	var c := root.get_final_transform() * b.get_global_rect().get_center()
	Input.warp_mouse(c)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = c
	e.global_position = c
	Input.parse_input_event(e)


func _esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)


func _node() -> int:
	return _flow.run.current_node().id if _flow.run != null and _flow.run.current_node() != null else -1


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 6000:
		L("超时"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game()
			L("trial %d：新游戏，章 %s" % [_trial, String(_flow.run.chapter.id) if _flow.run != null else "无"])
			_st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.accept_tutorial()
				_wait = 10
				return false
			if scr == GameFlow.Screen.EVENT:
				if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
				else: _flow.choose_event(0)
				_wait = 10
				return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next()
				_wait = 5
				return false
			_node0 = _node()
			L("地图上，节点 %d；按 Esc" % _node0)
			_esc()
			_wait = 10
			_st = 2
		2:
			var kb := _btn(UiText.t("map.pause_skip_tutorial"))
			L("暂停菜单开着 %s；跳过键 %s" % [str(_game.base().pause_open()), str(kb != null)])
			if kb == null: quit(1); return true
			_mouse(kb, true); _mouse(kb, false)
			_wait = 10
			_st = 3
		3:
			var no := _btn(UiText.t("skip_tut.no"))
			L("确认页 %s；【接着学】%s at %s" % [str(_game.base().skip_tutorial_open()), str(no != null), str(no.get_global_rect()) if no != null else ""])
			shot("t%d_confirm" % _trial)
			if _trial == 1:
				_mouse(no, true); _mouse(no, false)
			elif _trial == 2:
				no.pressed.emit()
			else:
				_mouse(no, true)
				_st = 30
				_wait = 3
				return false
			_st = 4
			_wait = 0
		30:
			L("trial 3 按下后：确认页 %s；屏 %s；节点 %d" % [str(_game.base().skip_tutorial_open()), GameFlow.Screen.keys()[scr], _node()])
			var no2 := _btn(UiText.t("skip_tut.no"))
			if no2 != null: _mouse(no2, false)
			else:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = false
				e.position = root.get_mouse_position()
				Input.parse_input_event(e)
			_st = 4
		4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20:
			L("trial %d 取消后第 %d 帧：屏 %s；节点 %d（原 %d）；暂停菜单 %s；确认页 %s" % [_trial, _st - 3, GameFlow.Screen.keys()[scr], _node(), _node0, str(_game.base().pause_open()) if _game.base().has_method("pause_open") else "-", str(_game.base().skip_tutorial_open()) if _game.base().has_method("skip_tutorial_open") else "-"])
			if _st == 5: shot("t%d_after" % _trial)
			_st += 1
		21:
			if _trial < 3:
				_trial += 1
				_flow.to_main_menu()
				_st = 0
				_f = 0
				_wait = 30
			else:
				quit(0)
				return true
	return false
