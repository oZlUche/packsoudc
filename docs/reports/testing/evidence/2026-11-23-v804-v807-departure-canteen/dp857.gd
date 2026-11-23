extends SceneTree
## 游戏测试 v8.04（PR #857，报告 383 第一批）：出征三屏走查。参数 <outdir>
## 新档 → 出征页（看军需牌没了）→ 真点【开始探索】直接进开局屏 → 第一屏只有角色一条（折叠），展开 / 换角色 → 第二屏配道具 → 第三屏地图 + 材料倾向（选一个方向）→ 出发
## → 走一步撤离，连做三次等万神院到来 → 测试辅助开食堂、发一枚随身技能 → 再点【开始探索】：信仰横条自己展开、先翻百科（试回车、Esc）、再教练层
## → 点灰着的狩猎之神、点日神 → 三条轮流展开量高度 → 第二屏随身技能圆槽 → 第三屏看倾向沿用 → 出发看信物进包 → 撤离后再进开局屏看沿用、不再放教练层
const TAG := "DP857"
const C355 := preload("res://tests/meta/test_canteen_355.gd")
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

var _k := 0


func _sp() -> Node:
	return _game.base() if _flow.screen == GameFlow.Screen.SETUP else null


func _faith_line() -> String:
	var r := _flow.run
	if r == null: return "（没有局）"
	var charms := []
	for inst in r.board.items():
		if Pantheon.is_charm((inst as ItemInstance).def): charms.append(String((inst as ItemInstance).def.id))
	return "角色 %s、奉 「%s」、有效「%s」、信仰开 %s、背包里的信物 %s、材料倾向 %s" % [String(r.character.id) if r.character != null else "-", String(r.selected_faith), String(r.active_faith_id()), str(r.faith_enabled), str(charms), str(r.get("bias") if "bias" in r else "-")]


func _bars(sp) -> String:
	var o := []
	for id in [sp.BAR_CHARACTER, sp.BAR_MEAL, sp.BAR_FAITH]:
		var b: FoldBar = sp.bar(id)
		o.append("%s %s%s「%s」" % [id, "在" if b.visible else "不在", "·开" if b.open else "·折", _labels_under(b.summary).replace("\n", " / ").left(80) if b.visible else ""])
	return "、".join(o)


func _room(sp) -> String:
	var design_h := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1000))
	var room: float = design_h - sp.PAGE_MARGIN - sp.NAV_ROOM - sp._title.get_parent().get_combined_minimum_size().y - sp.PAGE_SEP
	var h: float = (sp._bar_col as Control).get_combined_minimum_size().y
	var r: Rect2 = (sp._bar_col as Control).get_global_rect()
	return "横条一栏 %.0f / 可用 %.0f（%s），屏上 y %.0f–%.0f" % [h, room, "放得下" if h <= room else "超出", r.position.y, r.end.y]


func _bias(sp) -> String:
	var o := []
	var bb: Dictionary = sp.bias_buttons()
	for k in bb:
		var b := bb[k] as Button
		o.append("%s「%s」%s%s" % [String(k), b.text, "（灰）" if b.disabled else "", "✓" if b.button_pressed else ""])
	return "倾向开 %s、选着 %s；键 %s" % [str(_flow.bias_open()), String(sp.chosen_bias()), str(o)]


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


func _start_click() -> void:
	var sb: Button = _ms().get("_new_run_btn")
	if sb != null and sb.is_visible_in_tree(): _click(sb)
	elif sb != null: sb.pressed.emit()


func _setup_go() -> void:
	var sp := _sp()
	if sp == null: return
	if sp.page() < sp.last_page():
		sp.next_page(); return
	if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return
	_click(sp._enter_btn)


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code; e.physical_keycode = code; e.pressed = down
		Input.parse_input_event(e)


func _run_step_and_extract_ready() -> bool:
	if _flow.run.phase == RunState.Phase.PICK_SPAWN:
		_game.base().pick_spawn(_flow.run.map.entry_ids[0]); return false
	var moves: Array = _flow.run.travel.available_moves()
	var pick := int(moves[0])
	for mv in moves:
		var tt := NodeEvents.effective_type(_flow.run.map.get_node(int(mv)))
		if not (tt in [&"battle", &"elite", &"core"]): pick = int(mv); break
	_flow.step_to(pick)
	return true


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 20000:
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
			_tab("expedition"); _wait = 30; _st = 4
		4:
			var t := _labels_under(_ms()).replace("\n", " / ")
			L("出征页：含「军需」%s；字 %s" % [str(t.contains("军需") or t.to_lower().contains("supply")), t.left(500)])
			shot("expedition_tab")
			_start_click(); _wait = 40; _st = 5
		5:
			if scr == GameFlow.Screen.META: L("点了【开始探索】还在营地（屏 %d）" % scr); _start_click(); _wait = 40; return false
			var sp := _sp()
			if sp == null: _wait = 10; return false
			L("【开始探索】→ 开局屏：%d 页、第一页标题「%s」；%s" % [sp._pages.size(), sp._title.text, _bars(sp)])
			L("　　排版：%s" % _overflow(sp._pages[0]))
			shot("p1_folded_first")
			sp.bar(sp.BAR_CHARACTER).press(); _wait = 20; _st = 6
		6:
			var sp := _sp()
			L("点开角色条：%s；三栏可见 %s；%s" % [_bars(sp), str(sp._char_row.is_visible_in_tree()), _room(sp)])
			L("　　角色卡：%s" % _labels_under(sp._stat_plate).replace("\n", " / ").left(300))
			L("　　排版：%s" % _overflow(sp._pages[0]))
			shot("p1_character_open")
			if sp._characters.size() > 1: sp.choose_character(1)
			set_meta("char", String(sp.character().id))
			L("换成第二个角色 %s：头上「%s」" % [String(sp.character().id), (sp.bar(sp.BAR_CHARACTER).summary.get_node(^"HeadText") as Label).text])
			_key(KEY_ENTER); _wait = 25; _st = 7
		7:
			var sp := _sp()
			L("回车翻页 → 第 %d 页「%s」；随身技能圆槽 %d 个" % [sp.page() + 1, sp._title.text, sp.belt_slots().size()])
			L("　　排版：%s" % _overflow(sp._pages[1]))
			shot("p2_kit_first")
			sp.next_page(); _wait = 25; _st = 8
		8:
			var sp := _sp()
			L("第 %d 页「%s」；出发键「%s」；%s" % [sp.page() + 1, sp._title.text, sp._enter_btn.text, _bias(sp)])
			var pick: StringName = &""
			for k in sp.bias_buttons():
				if k != MaterialBias.NONE and not (sp.bias_buttons()[k] as Button).disabled: pick = k; break
			if pick != &"":
				_click(sp.bias_buttons()[pick]); set_meta("bias", String(pick))
			L("点倾向 %s → %s" % [String(pick), String(sp.chosen_bias())])
			L("　　排版：%s" % _overflow(sp._pages[2]))
			shot("p3_map_bias")
			_st = 9
		9:
			if scr == GameFlow.Screen.SETUP: _setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if not _run_step_and_extract_ready(): _wait = 20; return false
			L("第 %d 局开局：%s" % [_k + 1, _faith_line()])
			_wait = 60; _st = 10
		10:
			if (scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP) and not _settle(): _wait = 10; return false
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 11
		11:
			if scr == GameFlow.Screen.RESULT:
				_k += 1
				_game.base().proceed(); _wait = 60; _st = 12; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		12:
			if scr != GameFlow.Screen.META: return false
			L("第 %d 局撤离回营地：成功撤离 %d；万神院到了 %s" % [_k, _flow.meta.commissions.formal_extractions, str(Pantheon.arrived(_flow.meta))])
			if _k < 3:
				_tab("expedition"); _wait = 30; _st = 13; return false
			_wait = 60; _st = 14
		13:
			_start_click(); _wait = 40; _st = 9
		14:
			var arr: Control = _ms().arrival()
			if arr != null:
				var ok: Button = null
				for b in arr.find_children("*", "Button", true, false):
					if (b as Button).is_visible_in_tree(): ok = b
				_click(ok)
			C355._open(_flow)
			_flow.meta.belt_grants = {&"smoke_bomb": 2}
			_flow.meta.commissions.grants["bias"] = true
			L("测试辅助：开食堂（委托直接记完成）、发两枚烟雾弹随身技能、开材料倾向；到来通知点掉 %s" % str(arr != null))
			_tab("expedition"); _wait = 30; _st = 15
		15:
			_start_click(); _wait = 40; _st = 16
		16:
			var sp := _sp()
			if sp == null: L("点【开始探索】没进开局屏（屏 %d，选神弹窗 %s）" % [scr, str(_ms().has_method("god_pick"))]); _st = 99; return false
			L("万神院到后第一次出征：%s；翻开的百科 %s" % [_bars(sp), str(sp.god_book() != null)])
			if sp.god_book() != null:
				L("　　百科页：%s" % _labels_under(sp.god_book()).replace("\n", " / ").left(500))
				shot("god_book")
				_key(KEY_ENTER); _wait = 20; _st = 17; return false
			_st = 19
		17:
			var sp := _sp()
			L("翻书时按回车：还在第 %d 页、书开着 %s" % [sp.page() + 1, str(sp.god_book() != null)])
			_key(KEY_ESCAPE); _wait = 25; _st = 18
		18:
			var sp := _sp()
			L("按 Esc：书开着 %s、还在开局屏 %s、教练层 %s" % [str(sp != null and sp.god_book() != null), str(sp != null), str(sp != null and sp.god_coach() != null)])
			if sp != null and sp.god_book() != null: sp.close_god_book(); _wait = 20
			_st = 19
		19:
			var sp := _sp()
			var gc = sp.god_coach()
			if gc != null:
				var n := int(get_meta("gc", 0)) + 1
				set_meta("gc", n)
				L("选神教练层第 %d 步：%s" % [n, _labels_under(gc).replace("\n", " / ").left(300)])
				shot("god_coach_%d" % n)
				if n == 1:
					_key(KEY_ENTER); _wait = 15; set_meta("gc_enter", sp.page()); return false
				gc.next(); _wait = 15; return false
			L("教练层走完 %d 步（第一步按回车后在第 %d 页）；%s" % [int(get_meta("gc", 0)), int(get_meta("gc_enter", -1)) + 1, _bars(sp)])
			var keys := []
			for b in sp.faith_panel().find_children("Choose_*", "Button", true, false):
				keys.append("%s「%s」%s" % [String(b.name).trim_prefix("Choose_"), (b as Button).text, "（灰）" if (b as Button).disabled else ""])
			L("信仰横条：头上「%s」；键 %s" % [sp.faith_head_text(), str(keys)])
			L("　　%s" % _room(sp))
			L("　　排版：%s" % _overflow(sp._pages[0]))
			shot("p1_faith_open")
			var hunt := _named("Choose_hunt") as Button
			if hunt != null: _click(hunt)
			_wait = 20; _st = 20
		20:
			var sp := _sp()
			L("点灰着的狩猎之神：选的 %s、头上「%s」" % [String(Pantheon.choice(_flow.meta)), sp.faith_head_text()])
			_click(_named("Choose_sun")); _wait = 25; _st = 21
		21:
			var sp := _sp()
			var sun := _named("Choose_sun") as Button
			L("点日神：选的 %s、头上「%s」、键「%s」灰 %s" % [String(Pantheon.choice(_flow.meta)), sp.faith_head_text(), sun.text if sun != null else "-", str(sun.disabled) if sun != null else "-"])
			shot("p1_faith_sun")
			set_meta("bi", 0); _st = 40
		40:
			var sp := _sp()
			var ids := [sp.BAR_MEAL, sp.BAR_CHARACTER]
			var i := int(get_meta("bi"))
			if i > 0:
				var id: StringName = ids[i - 1]
				L("点开 %s：%s；%s" % [id, _bars(sp), _room(sp)])
				L("　　排版：%s" % _overflow(sp._pages[0]))
				if id == sp.BAR_MEAL: L("　　食物条：%s" % _labels_under(sp.bar(id)).replace("\n", " / ").left(300))
				shot("p1_%s_open" % id)
			if i < ids.size():
				sp.bar(ids[i]).press(); set_meta("bi", i + 1); _wait = 15; return false
			L("角色沿用：%s（上回 %s）" % [String(sp.character().id), str(get_meta("char"))])
			sp.bar(sp.BAR_CHARACTER).press(); _wait = 15; _st = 41
		41:
			shot("p1_all_folded")
			_sp().next_page(); _wait = 25; _st = 22
		22:
			var sp := _sp()
			var sl: Array = sp.belt_slots()
			L("配道具页随身技能圆槽：%d 个 %s" % [sl.size(), str(sl.map(func(s): return "×%d 看得见 %s 图 %s" % [s.count, str(s.is_visible_in_tree()), str(s.icon() != null)]))])
			L("　　排版：%s" % _overflow(sp._pages[1]))
			shot("p2_kit_belt")
			sp.next_page(); _wait = 25; _st = 23
		23:
			var sp := _sp()
			L("第三页（倾向刚开）：%s" % _bias(sp))
			L("　　排版：%s" % _overflow(sp._pages[2]))
			var pick: StringName = &""
			for k in sp.bias_buttons():
				if k != MaterialBias.NONE and not (sp.bias_buttons()[k] as Button).disabled: pick = k
			if pick != &"": _click(sp.bias_buttons()[pick]); set_meta("bias", String(pick))
			L("真点倾向 %s → 选着 %s" % [String(pick), String(sp.chosen_bias())])
			shot("p3_bias_pick")
			_st = 24
		24:
			if scr == GameFlow.Screen.SETUP: _setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("奉日神开局：%s" % _faith_line())
			_game.base().toggle_bag(); _wait = 25; _st = 25
		25:
			shot("bag_with_charm")
			_game.base().toggle_bag()
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 26
		26:
			if scr == GameFlow.Screen.RESULT: _game.base().proceed(); _wait = 60; _st = 27; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		27:
			if scr != GameFlow.Screen.META: return false
			_tab("expedition"); _wait = 30; _st = 28
		28:
			_start_click(); _wait = 40; _st = 29
		29:
			var sp := _sp()
			if sp == null: _wait = 10; return false
			L("再进开局屏：%s；百科 %s；教练层 %s；角色 %s" % [_bars(sp), str(sp.god_book() != null), str(sp.god_coach() != null), String(sp.character().id)])
			shot("p1_second_visit")
			sp.show_page(2); _wait = 20; _st = 30
		30:
			L("第三页：%s（上回点的 %s）" % [_bias(_sp()), str(get_meta("bias", "-"))])
			shot("p3_bias_remembered")
			_st = 99
		_:
			quit(0); return true
	return false
