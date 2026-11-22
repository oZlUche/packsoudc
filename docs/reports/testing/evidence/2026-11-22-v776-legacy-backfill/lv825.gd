extends SceneTree
## 游戏测试 v7.72（PR #825，报告 379）：局内经验值、每级三选一（刷新 / 删除）、以人为本逢 5 级多选、经验值管、状态界面、老存档 v7 → v8。参数 <outdir>
## 新档拒教程 → 测试辅助给「换牌」2 级、「剔牌」1 级 → 开局（A0，不奉神）→ 看经验值管 → 测试辅助加 50 点经验 → 地图上弹选牌 →
## 真点【换牌】→ 真点【剔牌】再点第 1 张 → 真点牌拿下 → 连着选完 → 加到 5 级看「以人为本」多一次 → Esc 收起、点经验值管再开 →
## 状态界面（黄字、这一局的牌）→ 存档退出再继续（等级和欠的选牌读回来）→ 测试辅助把局存档改成 v7 老格式（信力 30、选日神）→ 继续 → 看折算
const TAG := "LV825"
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

var _sp: Node = null


func _map() -> Node:
	return _game.base()


func _lvm() -> LevelModule:
	return LevelModule.of(_flow.run) if _flow.run != null else null


func _lv_line() -> String:
	var m := _lvm()
	if m == null: return "（没有等级模块）"
	var p := m.progress()
	return "Lv.%d、经验 %d / %d、欠选 %d、换牌剩 %d、剔牌剩 %d、以人为本 %s、牌 %s" % [m.level(), p.x, p.y, m.pending(), m.rerolls_left(), m.removals_left(), str(m.is_humanist()), str(m.taken_list().map(func(r): return "%s×%s" % [String(r.get("id", "")), str(r.get("count", ""))]))]


func _tube() -> Control:
	for n in root.find_children("*", "Control", true, false):
		var s = n.get_script()
		if s != null and String(s.resource_path).ends_with("level_widget.gd") and (n as Control).is_visible_in_tree(): return n
	return null


func _pick_line() -> String:
	var lp := _named("LevelPick")
	if lp == null: return "（选牌没弹）"
	var cards := []
	for i in 3:
		var c := _named("Card%d" % i)
		if c != null: cards.append(_labels_under(c).replace("\n", " "))
	return "选牌：%s；牌 %s；【换牌】%s；【剔牌】%s" % [_labels_under(lp).left(120), str(cards), _labels_under(_named("Reroll")), _labels_under(_named("Remove"))]


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
	if scr != GameFlow.Screen.MAP:
		return false
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); return false
	return true


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 14000:
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
			_flow.meta.tech_levels["level_reroll"] = 2
			_flow.meta.tech_levels["level_remove"] = 1
			_flow.derive_techs(); _flow.save_meta()
			L("测试辅助：科技「换牌」2 级、「剔牌」1 级")
			_flow.next_run_seed = 7
			_tab("expedition")
			set_meta("go", _f)
			_wait = 40; _st = 4
		4:
			if scr == GameFlow.Screen.META:
				var sb: Button = _ms().get("_new_run_btn")
				if _f - int(get_meta("go", 0)) > 200 and sb != null: sb.pressed.emit(); _wait = 30; return false
				if sb != null and sb.is_visible_in_tree(): _click(sb)
				_wait = 30; return false
			if scr != GameFlow.Screen.SETUP: return false
			for n in root.find_children("*", "", true, false):
				if n.has_method("step_difficulty") and n.has_method("depart"): _sp = n
			_st = 5
		5:
			if scr == GameFlow.Screen.SETUP:
				if _sp.needs_spawn(): _sp.pick_spawn(_sp._preview.entry_ids()[0]); _wait = 15; return false
				if not _sp.next_page(): _sp.depart()
				_wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_map().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var t := _tube()
			L("进地图：%s；经验值管「%s」%s" % [_lv_line(), _labels_under(t) if t != null and _labels_under(t) != "" else (t.call("text_of") if t != null and t.has_method("text_of") else "（没找到）"), (" 提示「%s」" % t.tooltip_text.left(120)) if t != null else ""])
			shot("map_start")
			var got := _lvm().gain(50.0, LevelModule.SRC_EVENT, "test")
			L("测试辅助：加 50 点经验（实得 %.1f）：%s" % [got, _lv_line()])
			_wait = 30; _st = 6
		6:
			L(_pick_line())
			shot("pick_first")
			set_meta("before", str(_map().level_pick_panel().offered()) if _map().level_pick_panel() != null else "-")
			_click(_named("Reroll")); _wait = 15; _st = 7
		7:
			L("真点【换牌】：原来 %s → 现在 %s；%s" % [str(get_meta("before")), str(_map().level_pick_panel().offered()), _lv_line()])
			_click(_named("Remove")); _wait = 12; _st = 8
		8:
			L("真点【剔牌】进删除模式：%s" % _pick_line())
			set_meta("before", str(_map().level_pick_panel().offered()))
			_click(_named("Card0")); _wait = 15; _st = 9
		9:
			L("删第 1 张：原来 %s → 现在 %s；%s" % [str(get_meta("before")), str(_map().level_pick_panel().offered()), _lv_line()])
			shot("after_remove")
			set_meta("before", str(_map().level_pick_panel().offered()))
			set_meta("hp", _flow.run.player_spec().max_hp if _flow.run.has_method("player_spec") else -1)
			_click(_named("Card0")); _wait = 15; _st = 10
		10:
			L("真点第 1 张拿下：%s；%s" % [str(get_meta("before")), _lv_line()])
			if _named("LevelPick") != null and _lvm().pending() > 0:
				L("　　还欠着，接着弹：%s" % _pick_line())
				_click(_named("Card1")); _wait = 15; return false
			L("选完：选牌收起 %s；%s" % [str(_named("LevelPick") == null), _lv_line()])
			shot("picked_all")
			var need := 0
			var m := _lvm()
			var lv0 := m.level()
			var got := m.gain(float(m.progress().y - m.progress().x), LevelModule.SRC_EVENT, "test")
			L("测试辅助：再加 %.1f 点到 %d 级：%s" % [got, m.level(), _lv_line()])
			_wait = 30; _st = 11
		11:
			if _lvm().level() < 5:
				var m := _lvm()
				if _named("LevelPick") != null: _click(_named("Card0")); _wait = 15; return false
				m.gain(float(m.progress().y - m.progress().x), LevelModule.SRC_EVENT, "test"); _wait = 30; return false
			L("到 5 级：%s" % _lv_line())
			L("　　" + _pick_line())
			shot("lv5_humanist")
			_st = 12
		12:
			if _named("LevelPick") != null and _lvm().pending() > 1:
				_click(_named("Card2")); _wait = 15; return false
			L("5 级还剩最后一次：%s；%s" % [_pick_line(), _lv_line()])
			var ev := InputEventKey.new(); ev.keycode = KEY_ESCAPE; ev.pressed = true
			root.push_input(ev)
			var ev2 := InputEventKey.new(); ev2.keycode = KEY_ESCAPE; ev2.pressed = false
			root.push_input(ev2)
			_wait = 15; _st = 13
		13:
			var t := _tube()
			L("按 Esc：选牌收起 %s；屏 %d；经验值管「%s」" % [str(_named("LevelPick") == null), _flow.screen, t.call("text_of") if t != null and t.has_method("text_of") else "-"])
			shot("dismissed")
			if t != null: _click(t)
			_wait = 15; _st = 14
		14:
			L("真点经验值管：%s" % _pick_line())
			_click(_named("Card0")); _wait = 15; _st = 15
		15:
			L("拿下最后一张：%s" % _lv_line())
			_map().toggle_bag(); _wait = 25; _st = 16
		16:
			var cc: Node = null
			for n in root.find_children("*", "", true, false):
				var s = n.get_script()
				if s != null and String(s.resource_path).ends_with("character_card.gd") and (n as Control).is_visible_in_tree(): cc = n; break
			L("状态界面：角色卡 %s" % (_labels_under(cc).replace("\n", " ").left(500) if cc != null else "（没找到）"))
			shot("status")
			_map().toggle_bag(); _wait = 15; _st = 17
		17:
			set_meta("lv", _lv_line())
			L("存档退出：%s" % str(_flow.save_and_quit())); _wait = 30; _st = 18
		18:
			_flow.continue_game(); _wait = 40; _st = 19
		19:
			if not _settle(): _wait = 10; return false
			L("读回来：%s（存前 %s）" % [_lv_line(), str(get_meta("lv"))])
			L("存档退出：%s" % str(_flow.save_and_quit())); _wait = 30; _st = 20
		20:
			var d = JSON.parse_string(FileAccess.get_file_as_string(_flow.save_path))
			if not (d is Dictionary): L("局存档读不成 JSON"); _st = 99; return false
			var keys := (d as Dictionary).keys()
			L("局存档顶层键 %s；版本 %s；modules 里 %s" % [str(keys), str(d.get("version", d.get("save_version", "?"))), str((d.get("modules", {}) as Dictionary).keys())])
			for k in ["version", "save_version"]:
				if d.has(k): d[k] = 7
			(d["modules"] as Dictionary).erase("level")
			d["faith_progress"] = {"sun": {"devotion": 30, "prayer": 25}, "brute": {"devotion": 50, "prayer": 50}}
			d["faith_selection"] = {"selected_id": "sun"}
			var fa := FileAccess.open(_flow.save_path, FileAccess.WRITE)
			fa.store_string(JSON.stringify(d)); fa.close()
			L("测试辅助（模拟 v7 老档）：版本改 7，删掉 modules.level；faith_progress 日神信力 30 / 祈愿 25、蛮神 50 / 50；选日神")
			_flow.continue_game(); _wait = 40; _st = 21
		21:
			if _flow.screen == GameFlow.Screen.MAIN_MENU and _f % 50 == 0: L("（还在主菜单）")
			if not _settle(): _wait = 10; return false
			L("读老档：%s（选日神但信物不在棋盘：应 6 级、欠 5 + 1 次）；所选的神「%s」、有效信仰「%s」" % [_lv_line(), String(_flow.run.selected_faith), String(_flow.run.active_faith_id())])
			_wait = 20; _st = 22
		22:
			L("老档回到地图：" + _pick_line())
			shot("legacy_pick")
			set_meta("lv", _lv_line())
			L("老档再存档退出：%s" % str(_flow.save_and_quit())); _wait = 30; _st = 23
		23:
			_flow.continue_game(); _wait = 40; _st = 24
		24:
			if not _settle(): _wait = 10; return false
			var dd = JSON.parse_string(FileAccess.get_file_as_string(_flow.save_path))
			L("再读回来：%s（存前 %s）；新存档 modules.level 有 backfill_bonus：%s" % [_lv_line(), str(get_meta("lv")), str((dd is Dictionary) and ((dd.get("modules", {}) as Dictionary).get("level", {}) as Dictionary).has("backfill_bonus"))])
			_st = 99
		_:
			quit(0); return true
	return false
