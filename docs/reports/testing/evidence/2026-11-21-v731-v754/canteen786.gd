extends SceneTree
## 游戏测试 v7.33（PR #786，报告 373）：灰灯食堂第二批 —— 收藏、改名、删除、一键重做、缺料标格、按角色写终值、开局屏第四页。参数 <outdir>
## 新档拒教程 → 测试辅助开食堂、往食材仓库放食材、摆一锅 → 真点「食堂」→【收藏】→ 改名 → 测试辅助把锅倒回仓库 → 真点菜单牌重做 →
## 测试辅助再倒回、扔掉蜂蜜罐 → 真点菜单牌（缺一样，锅上标格）→ 悬停食材看终值 → 收满 8 份、第 9 份 → 删一份 →
## 出征开局屏翻到第四页「本次准备」→ 真点另一份收藏 → 出发进地图看这一锅
const TAG := "C786"
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

var _pot0: Array = []


func _cp() -> Node:
	return _ms().canteen_panel()


func _c() -> Canteen:
	return _flow.meta.canteen


func _pot_back() -> void:
	for it in _c().pot.items():
		_c().pot.remove((it as ItemInstance).uid)
		_c().stash(it)
	_flow.meta.changed.emit()


func _to_pot(id: String) -> void:
	for it in _c().store.items():
		if String((it as ItemInstance).def.id) == id:
			_c().store.remove((it as ItemInstance).uid)
			if not _c().pot.try_add(it): _c().stash(it); L("（%s 放不进锅）" % id)
			return


func _menus() -> String:
	return "%d 份 %s；锅名「%s」；缺 %d 格" % [_c().menus.size(), str(_c().menus.map(func(m): return String(m.get("name", "")))), _c().menu_name(), _c().gaps().size()]


func _sub(key: String) -> void:
	_tab("logistics")
	_click(_ms()._sub_btns[key])


func _tips() -> String:
	var o := []
	for n in root.find_children("*", "", true, false):
		if n is Control and (n as Control).is_visible_in_tree() and (String(n.name).contains("Tip") or n.get_class() == "TooltipPanel"):
			var t := _labels_under(n)
			if t != "" and not o.has(t): o.append(t.left(260))
	for w in root.get_children(true):
		if w is Window and (w as Window).visible and w != root: o.append("窗 " + _labels_under(w).left(260))
	return " ‖ ".join(o) if not o.is_empty() else "（没看到提示窗）"


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 16000:
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
			Commissions.arrive(_flow.meta.commissions, 1)
			_assist_done(["legion_forge_token", "society_first_survey", "greylamp_check_scale", "greylamp_unsigned_letter", "greylamp_check_medkits", "greylamp_permit"], &"greylamp", 25)
			L("测试辅助：灰灯前置办成、声望 25；《开伙》%s；后勤小键 %s" % [_flow.meta.commissions.state_of(&"greylamp_canteen"), str(_ms()._sub_btns.keys())])
			_tab("commissions"); _wait = 20; _st = 30
		30:
			_click(_named("Sub_story")); _wait = 20; _st = 31
		31:
			L("《开伙》卡：%s" % _labels_under(_named("Card_greylamp_canteen")).left(200))
			_click(_named("Finish_greylamp_canteen")); _wait = 25; _st = 32
		32:
			L("真点《开伙》【完成】：状态 %s；食堂开 %s；现在的页 %s；后勤小键 %s" % [_flow.meta.commissions.state_of(&"greylamp_canteen"), str(_flow.canteen_open()), _ms().page(), str(_ms()._sub_btns.keys())])
			shot("after_canteen_finish")
			for id in ["wild_berry", "wild_berry", "wild_berry", "mountain_yam", "mountain_yam", "honey_jar", "game_meat", "sour_wheat"]: _put(id, _c())
			for id in ["mountain_yam", "wild_berry", "honey_jar", "game_meat"]: _to_pot(id)
			_pot0 = _ids(_c().pot)
			L("测试辅助：食材仓库 %s；锅 %s" % [str(_ids(_c().store)), str(_pot0)])
			if not _ms()._sub_btns.has("canteen"):
				L("后勤还没有「食堂」小键：回主菜单再继续")
				_flow.to_main_menu(); _wait = 30; _st = 33; return false
			_sub("canteen"); _wait = 25; _st = 4
		33:
			_flow.continue_game(); _wait = 40; _st = 34
		34:
			if _flow.screen != GameFlow.Screen.META: return false
			L("继续后后勤小键 %s" % str(_ms()._sub_btns.keys()))
			_sub("canteen"); _wait = 25; _st = 4
		4:
			L("真点「食堂」：%s；页上 %s" % [_menus(), _labels_under(_cp()).left(400)])
			L("　　按谁算终值：%s" % (_flow.canteen_viewer().display_name if _flow.canteen_viewer() != null else "-"))
			L("　　排版：%s" % _overflow(_cp()))
			shot("canteen")
			if _named("SaveMenu") == null: L("没有【收藏】键"); _st = 99; return false
			_click(_named("SaveMenu")); _wait = 20; _st = 5
		5:
			L("真点【收藏】：%s；收藏夹 %s" % [_menus(), _labels_under(_named("Menus"))])
			shot("saved")
			_click(_named("Menus").find_child("Rename", true, false)); _wait = 15; _st = 6
		6:
			var e := _named("NameEdit") as LineEdit
			L("真点【改名】：输入框 %s" % ("出来了「%s」" % e.text if e != null else "没出来"))
			if e != null:
				e.text = "猛火炖锅一二三四五六七"
				e.text_submitted.emit(e.text)
			_wait = 15; _st = 7
		7:
			L("改名（11 个字，上限 %d）：%s" % [Canteen.NAME_MAX, _menus()])
			_pot_back()
			L("测试辅助：锅倒回食材仓库：锅 %s；%s" % [str(_ids(_c().pot)), _menus()])
			_wait = 10; _st = 8
		8:
			_click(_named("Menus").find_child("Load", true, false)); _wait = 20; _st = 9
		9:
			var a := _ids(_c().pot); a.sort()
			var b := _pot0.duplicate(); b.sort()
			L("真点菜单牌重做：锅 %s（和原来 %s）；%s" % [str(a), "一样" if a == b else "不一样 %s" % str(b), _menus()])
			shot("reloaded")
			_pot_back()
			for it in _c().store.items():
				if String((it as ItemInstance).def.id) == "honey_jar": _c().store.remove((it as ItemInstance).uid)
			_flow.meta.changed.emit()
			L("测试辅助：再倒回，扔掉蜂蜜罐：食材仓库 %s" % str(_ids(_c().store)))
			_wait = 10; _st = 10
		10:
			_click(_named("Menus").find_child("Load", true, false)); _wait = 20; _st = 11
		11:
			L("缺蜂蜜罐时点菜单牌：锅 %s；%s；锅名标签 %s；缺料层 %s" % [str(_ids(_c().pot)), _menus(), _labels_under(_named("PotName")), "看得见" if _named("Gaps") != null else "看不见"])
			shot("gaps")
			var berry := -1
			for it in _c().store.items(): if String((it as ItemInstance).def.id) == "wild_berry": berry = (it as ItemInstance).uid
			var p = _cp()
			if berry >= 0:
				var r: Rect2 = p.store_view.item_rect(berry)
				_hover_at(p.store_view.global_position + r.get_center())
			_wait = 100; _st = 12
		12:
			L("悬停食材仓库里的野莓：%s" % _tips())
			L("　　野莓那一行（按当前角色）：%s" % ItemTooltip.canteen_line(_flow.items.get_def(&"wild_berry")))
			shot("tip_berry")
			_hover_at(Vector2(-10, -10))
			_wait = 10; _st = 13
		13:
			if _c().menus.size() < Canteen.MAX_MENUS and _named("SaveMenu") != null and _f < 9000:
				_click(_named("SaveMenu")); _wait = 12; return false
			var sb := _named("SaveMenu") as Button
			L("收满 %d 份：%s；【收藏】键 %s" % [Canteen.MAX_MENUS, _menus(), "灰了" if sb != null and sb.disabled else "还能点" if sb != null else "不在了"])
			if sb != null and not sb.disabled: _click(sb)
			_wait = 15; _st = 14
		14:
			L("第 9 次点【收藏】：%s；告示 %s" % [_menus(), str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", "")))])
			L("　　排版：%s" % _overflow(_cp()))
			shot("full")
			var last := _named("Menus").find_child("Menu7", true, false)
			_click(last.find_child("Delete", true, false) if last != null else null); _wait = 15; _st = 15
		15:
			L("删第 8 份：%s" % _menus())
			_put("honey_jar", _c())
			_pot_back()
			for id in ["wild_berry", "wild_berry", "mountain_yam"]: _to_pot(id)
			_c().save_menu("清淡")
			_pot_back()
			L("测试辅助：补回蜂蜜罐，另收一份「清淡」（野莓 ×2 山薯），锅倒空：%s" % _menus())
			_flow.save_meta()
			_tab("expedition"); _wait = 20; _st = 16
		16:
			_flow.next_run_seed = 31
			var sb: Button = _ms().get("_new_run_btn")
			if sb != null: _click(sb)
			_wait = 40; _st = 17
		17:
			if scr != GameFlow.Screen.SETUP: return false
			var sp: Node = null
			for n in root.find_children("*", "", true, false):
				if n.has_method("choose_menu") and n.has_method("depart"): sp = n
			if sp == null: L("开局屏没找到"); _st = 99; return false
			set_meta("sp", sp)
			if sp.page() < 3:
				if sp.needs_spawn() and sp.page() == 2: sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 15; return false
				if not sp.next_page(): L("翻不过第 %d 页" % (sp.page() + 1)); _st = 99
				_wait = 15; return false
			_wait = 20; _st = 18
		18:
			var sp: Node = get_meta("sp")
			L("开局屏第 %d 页：这一锅 %s；收藏键 %s" % [sp.page() + 1, _labels_under(_named("MealBlock")).left(300), str(sp.meal_buttons().map(func(b): return b.text))])
			L("　　排版：%s" % _overflow(_named("MealBlock")))
			shot("setup_meal")
			var bs: Array = sp.meal_buttons()
			var pick: Button = null
			for b in bs: if (b as Button).text.contains("清淡"): pick = b
			_click(pick if pick != null else (bs[0] if not bs.is_empty() else null)); _wait = 20; _st = 19
		19:
			var sp: Node = get_meta("sp")
			L("真点「清淡」：锅 %s；%s；这一锅 %s" % [str(_ids(_c().pot)), _menus(), _labels_under(_named("MealBlock")).left(300)])
			shot("setup_switched")
			var eb = sp.get("_enter_btn")
			if eb != null and (eb as Button).is_visible_in_tree(): _click(eb)
			else: sp.depart()
			_wait = 40; _st = 20
		20:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if scr == GameFlow.Screen.SETUP:
				var sp: Node = get_meta("sp")
				if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 15; return false
				sp.depart(); _wait = 30; return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var mod := MealModule.of(_flow.run)
			var spec := _flow.run.compile_player()
			L("进地图：锅里还剩 %d 件；饱腹 %s；每秒回血 固定 %.2f + 生命上限 %.2f%%" % [_c().pot.item_count(), str(mod.satiety) if mod != null else "（没吃）", spec.meal_regen_hp, spec.meal_regen_hp_pct])
			shot("run")
			_st = 99
		_:
			quit(0); return true
	return false
