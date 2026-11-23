extends SceneTree
## 游戏测试 v8.07（PR #860，报告 383 第二批）：食堂【固定】【开饭】到出征食物横条。参数 <outdir>
## 新档 → 测试辅助开食堂、放食材、存两份收藏（山薯、酸麦），锅里另摆一个山薯 → 进开局屏看没设固定是空锅、山薯回仓库 → 返回
## → 后勤食堂页真点第二份的【固定】→ 开局屏照它配锅、展开能换 → 返回 → 食堂页真点【开饭】→ 重开存档位看吃过的标记存着
## → 开局屏横条「已吃过」只读、换不了 → 出发看吃的是这一锅、锅空、标记清掉 → 撤离 → 测试辅助做一份「旧档」（删掉 fixed / eaten）读回
const TAG := "CT860"
const D383 := preload("res://tests/ui/test_departure_383.gd")
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print(TAG + " " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%s_%02d_%s.png" % [out, TAG.to_lower(), _shots, n])


func _mouse_at(p_canvas: Vector2, button: int) -> void:
	var c := root.get_final_transform() * p_canvas
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _hover_at(p_canvas: Vector2) -> void:
	var c := root.get_final_transform() * p_canvas
	Input.warp_mouse(c)
	var e := InputEventMouseMotion.new()
	e.position = c
	e.global_position = c
	Input.parse_input_event(e)


func _click(b: Control) -> void:
	if b == null: L("（要点的键不在）"); return
	var p := b.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(b)
			break
		p = p.get_parent()
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


func _named(nm: String) -> Control:
	for n in root.find_children(nm, "Control", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null


func _labels_under(n: Node) -> String:
	if n == null: return "（无）"
	var o := []
	for l in n.find_children("*", "", true, false):
		if not (l is Label or l is RichTextLabel or l is Button) or not (l as Control).is_visible_in_tree(): continue
		var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else ((l as Button).text if l is Button else (l as Label).text)
		if t.strip_edges() != "": o.append(("[%s]" if l is Button else "%s") % t.strip_edges().replace("\n", " "))
	return " / ".join(o)


func _ms() -> Node:
	return _game.base()


func _tab(key: String) -> void:
	_click(_ms()._tab_btns[key])


func _put(id: String, grid = null) -> ItemInstance:
	var d := _flow.items.get_def(StringName(id))
	if d == null: L("（道具库没有 %s）" % id); return null
	var inst := ItemInstance.create(d, 0)
	inst.uid = _flow.meta.allocate_uid()
	var g = grid if grid != null else _flow.meta.warehouse
	if g is Canteen: (g as Canteen).stash(inst)
	else: g.try_add(inst)
	return inst


func _ids(g) -> Array:
	return g.items().map(func(i): return String((i as ItemInstance).def.id))


## 新档、拒教程，到营地返回 true
func _boot() -> bool:
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 30; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 30; _st = 2
		2:
			if _flow.screen == GameFlow.Screen.META: return true
	return false


## 测试辅助：把 [param ids] 这几份委托直接记办成（前置一并办），声望补到 [param rep]
func _assist_done(ids: Array, faction: StringName = &"", rep: int = 0) -> void:
	var bk := _flow.meta.commissions
	for id in ids:
		var d := Commissions.def(StringName(id))
		if d == null or bk.state_of(d.id) == CommissionBook.DONE: continue
		if not bk.taken().has(d.id) and bk.state_of(d.id) != CommissionBook.READY: Commissions.take(bk, d)
		Commissions._complete(_flow.meta, d, _flow.items)
	if faction != &"":
		while bk.rep_of(faction) < rep: bk.rep[String(faction)] = bk.rep_of(faction) + 1
	_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()


## 排版溢出：可见的字落在它最近的 PanelContainer 外，或者不换行的字比自己的框宽
func _overflow(top: Node) -> String:
	if top == null: return "（无）"
	var bad := []
	var n_checked := 0
	for l in top.find_children("*", "", true, false):
		if not (l is Label or l is Button or l is RichTextLabel) or not (l as Control).is_visible_in_tree(): continue
		var c := l as Control
		n_checked += 1
		var r := c.get_global_rect()
		var p := c.get_parent()
		while p != null and not (p is PanelContainer): p = p.get_parent()
		var t: String = (l as RichTextLabel).get_parsed_text() if l is RichTextLabel else ((l as Button).text if l is Button else (l as Label).text)
		t = t.strip_edges().replace("\n", " ").left(24)
		if p != null and p != c and not (p as Control).get_global_rect().grow(2).encloses(r):
			bad.append("「%s」出 %s 框" % [t, p.name])
		elif l is Label and (l as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (l as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and c.get_minimum_size().x > c.size.x + 1:
			bad.append("「%s」比自己的框宽（%d > %d）" % [t, int(c.get_minimum_size().x), int(c.size.x)])
	return "查了 %d 处，%s" % [n_checked, "没有溢出" if bad.is_empty() else "溢出 %d：%s" % [bad.size(), "；".join(bad.slice(0, 6))]]



func _sp() -> Node:
	return _game.base() if _flow.screen == GameFlow.Screen.SETUP else null


func _cn() -> Canteen:
	return _flow.meta.canteen


func _state() -> String:
	var c := _cn()
	return "固定 %d、吃过 %s、锅 %d 件「%s」、仓库 %s" % [c.fixed, str(c.eaten), c.pot.item_count(), c.menu_name(), str(_ids(c.store))]


func _panel_line() -> String:
	var p = _ms().canteen_panel()
	if p == null: return "（没有食堂页）"
	var fx := []
	for b in p.find_children("Fix", "Button", true, false): fx.append("「%s」" % (b as Button).text)
	var eat := p.find_child("Eat", true, false) as Button
	var picks := []
	for b in p.find_children("*", "Button", true, false):
		var bb := b as Button
		if bb.get_parent().find_child("Fix", false, false) != null and bb.name != "Fix" and bb.name != "Rename" and bb.text != "":
			picks.append("「%s」%s" % [bb.text, "（灰）" if bb.disabled else ""]); break
	return "【固定】键 %s；【开饭】「%s」灰 %s 悬停「%s」；收藏第一键 %s；锅在拖拽层 %s" % [str(fx), eat.text, str(eat.disabled), eat.tooltip_text, str(picks), str(p.drag._views.has(p.pot_view)) if "drag" in p and p.drag != null else "-"]


func _meal(sp) -> String:
	var b: FoldBar = sp.bar(sp.BAR_MEAL)
	return "食物横条 在 %s 开 %s；头「%s」；收藏键 %d；只读说明 %s" % [str(b.visible), str(b.open), sp.meal_head_text(), sp.meal_buttons().size(), str(sp._meal_box.get_node_or_null(^"EatenNote") != null)]


func _start_click() -> void:
	var sb: Button = _ms().get("_new_run_btn")
	if sb != null and sb.is_visible_in_tree(): _click(sb)
	elif sb != null: sb.pressed.emit()


func _settle() -> bool:
	var scr := _flow.screen
	if scr == GameFlow.Screen.EVENT:
		if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
		else:
			var top = _game.overlay() if _game.overlay() != null else _game.base()
			if top != null and top.has_method("choose_event"): top.choose_event(0)
			elif top != null and top.has_method("proceed"): top.proceed()
			else: _flow.resume()
		return false
	if scr != GameFlow.Screen.MAP: return false
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); return false
	return true


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 12000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
	if _st < 3:
		if _boot(): _st = 3
		return false
	match _st:
		3:
			D383._two_menus(_flow)
			var c := _cn()
			var yam := c.store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == &"mountain_yam")[0] as ItemInstance
			c.store.remove(yam.uid); c.pot.place(yam, Vector2i(0, 0), 0)
			_flow.save_meta()
			L("测试辅助：开食堂、存两份收藏「%s」「%s」、锅里摆一个山薯：%s" % [c.menus[0]["name"], c.menus[1]["name"], _state()])
			_tab("expedition"); _wait = 30; _st = 4
		4:
			_start_click(); _wait = 40; _st = 5
		5:
			var sp := _sp()
			if sp == null: _wait = 10; return false
			L("没设固定，进开局屏：%s；%s" % [_state(), _meal(sp)])
			sp.open_bar(sp.BAR_MEAL); _wait = 15; _st = 6
		6:
			var sp := _sp()
			L("　　展开：%s；%s" % [_meal(sp), _labels_under(sp.bar(sp.BAR_MEAL)).replace("\n", " / ").left(300)])
			shot("meal_no_fixed")
			sp.cancel(); _wait = 30; _st = 7
		7:
			if scr != GameFlow.Screen.META: return false
			_tab("logistics"); _wait = 25; _st = 8
		8:
			_click(_ms()._sub_btns["canteen"]); _wait = 30; _st = 9
		9:
			L("食堂页：%s；%s" % [_panel_line(), _state()])
			L("　　排版：%s" % _overflow(_ms().canteen_panel()))
			shot("canteen_before")
			var fx: Array = _ms().canteen_panel().find_children("Fix", "Button", true, false)
			_click(fx[1]); _wait = 20; _st = 10
		10:
			L("真点第二份的【固定】：%s；%s" % [_state(), _panel_line()])
			shot("canteen_fixed")
			var fx: Array = _ms().canteen_panel().find_children("Fix", "Button", true, false)
			_click(fx[0]); _wait = 20; _st = 11
		11:
			L("再点第一份的【固定】（应换成第一份）：%s" % _state())
			var fx: Array = _ms().canteen_panel().find_children("Fix", "Button", true, false)
			_click(fx[0]); _wait = 20; _st = 12
		12:
			L("再点一次第一份（取消固定）：%s" % _state())
			var fx: Array = _ms().canteen_panel().find_children("Fix", "Button", true, false)
			_click(fx[1]); _wait = 20; _st = 13
		13:
			L("设回第二份「酸麦」：%s" % _state())
			_tab("expedition"); _wait = 30; _st = 14
		14:
			_start_click(); _wait = 40; _st = 15
		15:
			var sp := _sp()
			if sp == null: _wait = 10; return false
			L("设了固定，进开局屏：%s；%s" % [_state(), _meal(sp)])
			sp.open_bar(sp.BAR_MEAL); _wait = 15; _st = 16
		16:
			var sp := _sp()
			var tips: Array = sp.meal_buttons().map(func(b): return "「%s」%s" % [(b as Button).text, "悬停带固定配方" if (b as Button).tooltip_text.contains(UiText.t("canteen.fixed_tip").left(4)) else ""])
			L("　　展开：%s；收藏键 %s" % [_meal(sp), str(tips)])
			shot("meal_fixed")
			sp.cancel(); _wait = 30; _st = 17
		17:
			if scr != GameFlow.Screen.META: return false
			_tab("logistics"); _wait = 25; _st = 18
		18:
			_click(_ms()._sub_btns["canteen"]); _wait = 30; _st = 19
		19:
			L("回食堂页（锅照固定配好了）：%s；%s" % [_state(), _panel_line()])
			_click(_ms().canteen_panel().find_child("Eat", true, false)); _wait = 25; _st = 20
		20:
			L("真点【开饭】：%s；%s" % [_state(), _panel_line()])
			shot("canteen_eaten")
			_flow.use_slot(_flow.slot); _wait = 40; _st = 21
		21:
			if scr != GameFlow.Screen.META: return false
			L("重开存档位：%s" % _state())
			_tab("expedition"); _wait = 30; _st = 22
		22:
			_start_click(); _wait = 40; _st = 23
		23:
			var sp := _sp()
			if sp == null: _wait = 10; return false
			L("吃过了，进开局屏：%s；%s" % [_state(), _meal(sp)])
			sp.open_bar(sp.BAR_MEAL); _wait = 15; _st = 24
		24:
			var sp := _sp()
			L("　　展开：%s；%s" % [_meal(sp), _labels_under(sp.bar(sp.BAR_MEAL)).replace("\n", " / ").left(300)])
			L("　　排版：%s" % _overflow(sp._pages[0]))
			shot("meal_eaten")
			L("　　测试辅助硬换第一份：缺料 %d、%s" % [sp.choose_menu(0).size(), _state()])
			_st = 25
		25:
			var sp := _sp()
			if sp != null:
				if sp.page() < sp.last_page(): sp.next_page(); _wait = 15; return false
				if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 15; return false
				sp.depart(); _wait = 40; return false
			if not _settle(): _wait = 10; return false
			var mod := MealModule.of(_flow.run)
			L("出发：吃了 %s（%s）；%s" % [str(mod != null and mod.has_meal()), str(mod.get("meal_name") if mod != null and "meal_name" in mod else "-"), _state()])
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 26
		26:
			if scr == GameFlow.Screen.RESULT: _game.base().proceed(); _wait = 60; _st = 27; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		27:
			if scr != GameFlow.Screen.META: return false
			var c := _cn()
			c.load_menu(1); c.eaten = true
			_flow.save_meta()
			var path := _flow.meta_path
			var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var had := [d["canteen"].has("fixed"), d["canteen"].has("eaten"), d["canteen"].get("fixed"), d["canteen"].get("eaten")]
			d["canteen"].erase("fixed"); d["canteen"].erase("eaten")
			var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(JSON.stringify(d, "  ")); f.close()
			L("测试辅助（旧档）：锅照酸麦摆、记吃过、存档；存档里 fixed/eaten 原有 %s → 删掉这两项" % str(had))
			_flow.use_slot(_flow.slot); _wait = 40; _st = 28
		28:
			if scr != GameFlow.Screen.META: return false
			L("旧档读回：%s" % _state())
			_tab("expedition"); _wait = 30; _st = 29
		29:
			_start_click(); _wait = 40; _st = 30
		30:
			var sp := _sp()
			if sp == null: _wait = 10; return false
			L("旧档进开局屏：%s；%s" % [_state(), _meal(sp)])
			_st = 99
		_:
			quit(0); return true
	return false
