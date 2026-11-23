extends SceneTree
## 游戏测试 v8.16（PR #869，报告 383 第三批）：食物横条七种状态、离开第一屏的确认弹窗、出发那一刻才扣食材。参数 <outdir>
## 一份存档连着走：空锅 → 食堂真点应用「酸麦」（锅里摆着没开饭）→ 开局屏真点继续：弹窗 → 留下确认 → 真点【确认这一锅】→ 出发吃
## → 上次配方够料（自动复用，返回不扣）→ 出发吃 → 上次配方缺料（横条里应用缺料配方弹窗；不管就出发 = 不吃、下次为空）
## → 锅里摆自由组合 → 确认出发 → 上次组合够料 → 缺料（吃剩下的）→ 食堂真点开饭 → 开过饭（锁）→ 出发
const TAG := "CT869"
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

var _phase := 0


func _sp() -> Node:
	return _game.base() if _flow.screen == GameFlow.Screen.SETUP else null


func _cn() -> Canteen:
	return _flow.meta.canteen


func _add(id: String, n: int = 1) -> void:
	for i in n:
		_cn().store.try_add(D383.C355._inst(_flow.items, StringName(id), _flow.meta.allocate_uid()))


func _drop(id: String) -> void:
	D383._drop_store(_cn(), StringName(id))


func _st_line() -> String:
	var c := _cn()
	return "仓库 %s、锅 %s、开过饭 %s、上次 %s" % [str(_ids(c.store)), str(_ids(c.pot)), str(c.eaten), str({"kind": c.last.get("kind", ""), "name": c.last.get("name", ""), "格": (c.last.get("cells", []) as Array).size()}) if not c.last.is_empty() else "（空）"]


func _bar(sp) -> String:
	var b: FoldBar = sp.bar(sp.BAR_MEAL)
	return "状态 %s；头「%s」；锁 %s；效果 %d 条" % [String(sp.meal_state()), sp.meal_head_text(), str(b.get("locked") if "locked" in b else "?"), int(sp.meal_effect().get("count", 0))]


func _notice() -> String:
	var sp := _sp()
	var n = sp.meal_notice if sp != null else _ms().canteen_panel().short_notice
	if n == null or not is_instance_valid(n) or not n.is_inside_tree(): return "（没有弹窗）"
	return "弹窗：%s；键 %s" % [_labels_under(n).replace("\n", " / "), str(n.keys.map(func(k): return (k as Button).text))]


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


## 出发并撤离；返回 true = 回到营地了
var _dep := 0
func _depart_and_back(label: String) -> bool:
	var scr := _flow.screen
	match _dep:
		0:
			var sp := _sp()
			if sp == null: return false
			if sp._notice_up(): L("（意外弹窗：%s）" % _notice()); sp.meal_notice.keys[0].pressed.emit(); return false
			if sp.page() < sp.last_page(): sp.next_page(); return false
			if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return false
			sp.depart(); _dep = 1; return false
		1:
			if not _settle(): return false
			var mod := MealModule.of(_flow.run)
			L("%s → 出发：这一局吃到 %s；%s" % [label, str(mod != null and mod.has_meal()), _st_line()])
			_flow.run.force_extract(); _flow.resume(); _dep = 2; return false
		2:
			if scr == GameFlow.Screen.RESULT: _game.base().proceed(); _dep = 3; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle()
			return false
		3:
			if scr != GameFlow.Screen.META: return false
			_dep = 0; return true
	return false


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 20000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	if _st < 3:
		if _boot(): _st = 3
		return false
	_wait = 15
	match _st:
		3:
			D383._two_menus(_flow); _add("sour_wheat", 1); _add("mountain_yam", 3); _add("fowl_leg", 2)
			_flow.save_meta()
			L("测试辅助：开食堂、存配方「山薯」「酸麦」、补食材：%s" % _st_line())
			_tab("expedition"); _st = 4
		4:
			_start_click(); _wait = 30; _st = 5
		5:
			var sp := _sp()
			if sp == null: return false
			L("A 第一次：%s；%s" % [_bar(sp), _st_line()])
			shot("a_empty")
			sp.cancel(); _st = 6
		6:
			if _flow.screen != GameFlow.Screen.META: return false
			_tab("logistics"); _st = 7
		7:
			_click(_ms()._sub_btns["canteen"]); _wait = 25; _st = 8
		8:
			var row = _ms().canteen_panel().find_child("Menu1", true, false)
			L("食堂页配方行：%s；【固定】键 %d 个" % [_labels_under(row).replace("\n", " / "), _ms().canteen_panel().find_children("Fix", "Button", true, false).size()])
			_click(row.get_child(0)); _st = 9
		9:
			L("真点应用「酸麦」：%s；%s" % [_st_line(), _notice()])
			_tab("expedition"); _st = 10
		10:
			_start_click(); _wait = 30; _st = 11
		11:
			var sp := _sp()
			if sp == null: return false
			L("B 锅里摆着没开饭：%s" % _bar(sp))
			shot("b_unconfirmed")
			_click(sp._enter_btn); _st = 12
		12:
			var sp := _sp()
			L("真点【继续】：还在第 %d 页；%s" % [sp.page() + 1, _notice()])
			shot("b_leave_notice")
			_click(sp.meal_notice.key(UiText.t("canteen.leave_stay"))); _st = 13
		13:
			var sp := _sp()
			var cb := sp._meal_box.find_child("ConfirmMeal", true, false) as Button
			L("真点【留下确认】：第 %d 页、食物条展开 %s、确认键 %s" % [sp.page() + 1, str(sp.bar(sp.BAR_MEAL).open), ("「%s」" % cb.text) if cb != null else "没有"])
			L("　　展开：%s" % _labels_under(sp.bar(sp.BAR_MEAL)).replace("\n", " / ").left(400))
			L("　　排版：%s" % _overflow(sp._pages[0]))
			shot("b_stay_open")
			_click(cb); _st = 14
		14:
			var sp := _sp()
			L("真点【确认这一锅】：%s；%s" % [_bar(sp), _st_line()])
			shot("b_confirmed")
			_click(sp._enter_btn); _st = 15
		15:
			var sp := _sp()
			L("确认后点【继续】：第 %d 页；%s" % [sp.page() + 1, _notice()])
			_st = 16
		16:
			if _depart_and_back("B 确认了的那一锅"): _tab("expedition"); _st = 17
		17:
			_start_click(); _wait = 30; _st = 18
		18:
			var sp := _sp()
			if sp == null: return false
			L("C 上次配方、够料：%s；%s" % [_bar(sp), _st_line()])
			shot("c_menu")
			sp.cancel(); _st = 19
		19:
			if _flow.screen != GameFlow.Screen.META: return false
			L("C 返回基地（取消出征）：%s" % _st_line())
			_start_click(); _wait = 30; _st = 20
		20:
			if _sp() == null: return false
			_st = 21
		21:
			if _depart_and_back("C 上次配方够料"):
				_drop("sour_wheat"); _flow.save_meta()
				L("测试辅助：仓库里的酸麦全拿走：%s" % _st_line())
				_tab("expedition"); _st = 22
		22:
			_start_click(); _wait = 30; _st = 23
		23:
			var sp := _sp()
			if sp == null: return false
			L("D 上次配方、缺料：%s；%s" % [_bar(sp), _st_line()])
			shot("d_menu_short")
			sp.open_bar(sp.BAR_MEAL); _st = 24
		24:
			var sp := _sp()
			var keys: Array = sp.meal_buttons().map(func(b): return "「%s」" % (b as Button).text)
			L("　　展开：%s；应用键 %s" % [_labels_under(sp.bar(sp.BAR_MEAL)).replace("\n", " / ").left(400), str(keys)])
			_click(sp.meal_buttons()[1]); _st = 25
		25:
			var sp := _sp()
			L("　　真点应用缺料的「酸麦」：%s；%s" % [_notice(), _bar(sp)])
			shot("d_apply_short_notice")
			if sp._notice_up(): _click(sp.meal_notice.keys[0])
			_st = 26
		26:
			var sp := _sp()
			_click(sp.meal_buttons()[0]); _st = 27
		27:
			var sp := _sp()
			L("　　真点应用够料的「山薯」：%s；%s" % [_notice(), _bar(sp)])
			sp.cancel(); _st = 28
		28:
			if _flow.screen != GameFlow.Screen.META: return false
			L("　　取消出征：%s" % _st_line())
			_start_click(); _wait = 30; _st = 29
		29:
			var sp := _sp()
			if sp == null: return false
			L("D 再进来（应还是缺料）：%s" % _bar(sp))
			shot("d_again")
			_st = 30
		30:
			if _depart_and_back("D 配方缺料不管"): _st = 31
		31:
			L("D 之后：plan %s" % String(_cn().plan()["state"]))
			for id in ["mountain_yam", "fowl_leg"]:
				var it := _cn().store.items().filter(func(i: ItemInstance) -> bool: return i.def.id == StringName(id))[0] as ItemInstance
				_cn().store.remove(it.uid); _cn().pot.try_add(it, true)
			_cn().active = -1
			_flow.save_meta()
			L("测试辅助：锅里摆山薯 + 禽腿（不照配方）：%s" % _st_line())
			_tab("expedition"); _st = 32
		32:
			_start_click(); _wait = 30; _st = 33
		33:
			var sp := _sp()
			if sp == null: return false
			L("E 锅里自由组合、没开饭：%s" % _bar(sp))
			sp.open_bar(sp.BAR_MEAL); _st = 34
		34:
			var sp := _sp()
			_click(sp._meal_box.find_child("ConfirmMeal", true, false)); _st = 35
		35:
			L("E 确认：%s" % _bar(_sp()))
			_st = 36
		36:
			if _depart_and_back("E 自由组合"): _tab("expedition"); _st = 37
		37:
			_start_click(); _wait = 30; _st = 38
		38:
			var sp := _sp()
			if sp == null: return false
			L("F 上次组合、够料：%s；%s" % [_bar(sp), _st_line()])
			shot("f_free")
			sp.cancel(); _st = 39
		39:
			if _flow.screen != GameFlow.Screen.META: return false
			_drop("fowl_leg"); _flow.save_meta()
			L("测试辅助：仓库里的禽腿全拿走：%s" % _st_line())
			_start_click(); _wait = 30; _st = 40
		40:
			var sp := _sp()
			if sp == null: return false
			L("G 上次组合、缺料：%s" % _bar(sp))
			shot("g_free_short")
			_st = 41
		41:
			if _depart_and_back("G 组合缺料"): _tab("logistics"); _st = 42
		42:
			_click(_ms()._sub_btns["canteen"]); _wait = 25; _st = 43
		43:
			_click(_ms().canteen_panel().find_child("Menu0", true, false).get_child(0)); _st = 44
		44:
			var eat := _ms().canteen_panel().find_child("Eat", true, false) as Button
			L("食堂真点应用「山薯」：%s；【开饭】「%s」灰 %s" % [_st_line(), eat.text, str(eat.disabled)])
			_click(eat); _st = 45
		45:
			var eat := _ms().canteen_panel().find_child("Eat", true, false) as Button
			L("真点【开饭】：%s；键「%s」灰 %s；%s" % [_st_line(), eat.text, str(eat.disabled), _notice()])
			shot("h_canteen_eaten")
			_tab("expedition"); _st = 46
		46:
			_start_click(); _wait = 30; _st = 47
		47:
			var sp := _sp()
			if sp == null: return false
			L("H 开过饭：%s" % _bar(sp))
			shot("h_eaten")
			sp.open_bar(sp.BAR_MEAL); _st = 48
		48:
			var sp := _sp()
			L("　　展开：%s；应用键 %d；硬换第一份 → %d" % [_labels_under(sp.bar(sp.BAR_MEAL)).replace("\n", " / ").left(300), sp.meal_buttons().size(), sp.choose_menu(0)])
			shot("h_eaten_open")
			_st = 49
		49:
			if _depart_and_back("H 开过饭"): _st = 50
		50:
			L("H 之后：plan %s；%s" % [String(_cn().plan()["state"]), _st_line()])
			_st = 99
		_:
			quit(0); return true
	return false
