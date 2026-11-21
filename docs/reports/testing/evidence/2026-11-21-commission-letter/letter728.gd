extends SceneTree
## 游戏测试 PR #728：未署名的信（commission_letter）定稿图。参数 <outdir> [seed]
## 新档拒教程 → 委托页剧情真点灰灯的【接下】《未署名的信》（或测试辅助接上）→ 直接开自由模式 →
## 局内背包里找信：记图标路径、格子位置 → 鼠标悬停看悬浮窗 → 截图
var out := ""
var seed_ := 41
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _uid := -1


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: seed_ = int(a[1])
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("L728 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/letter_%02d_%s.png" % [out, _shots, n])


func _hover_at(p_canvas: Vector2) -> void:
	var c := root.get_final_transform() * p_canvas
	Input.warp_mouse(c)
	var e := InputEventMouseMotion.new()
	e.position = c
	e.global_position = c
	Input.parse_input_event(e)


func _tip_text() -> String:
	var o := []
	for n in root.find_children("*", "", true, false):
		if n is HoverTip:
			for l in n.find_children("*", "", true, false):
				if (l is Label or l is RichTextLabel) and (l as Control).is_visible_in_tree():
					var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else (l as Label).text
					if t.strip_edges() != "": o.append(t.strip_edges().replace("\n", " ⏎ "))
	return " | ".join(o) if not o.is_empty() else "（没有悬浮窗）"


func _item_global_rect(uid: int) -> Rect2:
	for n in root.find_children("*", "", true, false):
		if n is ContainerView and (n as Control).is_visible_in_tree():
			var cv := n as ContainerView
			var cont = cv.container()
			if cont != null and cont.has_method("get_item") and cont.get_item(uid) != null:
				var r := cv.item_rect(uid)
				if r.size != Vector2.ZERO: return Rect2(cv.get_global_rect().position + r.position, r.size)
	return Rect2()


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 8000: L("超时 st %d" % _st); quit(1); return true
	if _wait > 0: _wait -= 1; return false
	var scr := _flow.screen
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open(): b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240: _flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			if scr != GameFlow.Screen.META: return false
			var d := _flow.items.get_def(&"commission_letter")
			var p := "res://assets/items/commission_letter.png"
			L("道具定义：%s；名字「%s」；说明「%s」；图 %s 在 %s；@2x 在 %s" % [str(d != null), Names.of(d) if d != null else "", d.description if d != null else "", p, str(ResourceLoader.exists(p)), str(ResourceLoader.exists("res://assets/items/@2x/commission_letter.png"))])
			var bk := _flow.meta.commissions
			var cd := Commissions.def(&"greylamp_unsigned_letter")
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]: _flow.report_commission(id)
			_flow.sync_commissions()
			L("办完三份开放单后：《未署名的信》%s，原因「%s」" % [bk.state_of(&"greylamp_unsigned_letter"), Commissions.why_not(bk, cd)])
			if not bk.taken().has(&"greylamp_unsigned_letter"): L("测试辅助接《未署名的信》：%s" % str(Commissions.take(bk, cd)))
			_flow.save_meta()
			_flow.begin_direct(_flow.chapter_of(&"free_mode"), seed_); _wait = 30; _st = 3
		3:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			for it in _flow.run.board.items():
				if String((it as ItemInstance).def.id) == "commission_letter": _uid = (it as ItemInstance).uid
			L("进图：背包里有信 %s（uid %d）" % [str(_uid >= 0), _uid])
			if _uid < 0: _st = 99; return false
			var ms = _game.base()
			if ms != null and ms.has_method("toggle_bag"): ms.toggle_bag(); L("打开背包")
			_wait = 40; _st = 4
		4:
			var n_c := 0
			for c in root.find_children("*", "CoachOverlay", true, false):
				if (c as Control).is_visible_in_tree(): (c as CoachOverlay).dismiss(); n_c += 1
			if n_c > 0: L("收起教程纸条 %d 张" % n_c); _wait = 20; return false
			var r := _item_global_rect(_uid)
			L("信在屏上：%s" % str(r))
			if r.size == Vector2.ZERO: shot("map_no_rect"); _st = 99; return false
			_hover_at(r.get_center()); _wait = 60; _st = 5
		5:
			L("悬停：%s" % _tip_text())
			shot("hover_letter")
			_hover_at(Vector2(5, 5)); _wait = 20; _st = 6
		6:
			shot("bag_letter")
			_st = 99
		_:
			quit(0); return true
	return false
