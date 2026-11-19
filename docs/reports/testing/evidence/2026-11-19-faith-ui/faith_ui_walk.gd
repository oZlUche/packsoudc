extends SceneTree
## 游戏测试 v6.45（信仰重构 A，报告 329）真实界面走查。参数：<outdir> <mode>
##   ui  ：开场一问【不需要】→ 直开常规图 → 棋盘塞蛮神、日神两件信物（测试辅助）→ 按 B 开背包，右键信物、真点「奉为主信仰」/「不再奉神」；
##         看顶端栏三态（空槽 / 徽记 + 阶 / 压暗 +「联系中断」）、悬浮窗；挪动、后放日神不改信；主信物挪到地上 = 中断、挪回恢复；存档回主菜单再继续，选择还在
##   old ：存档里已经有 v6.44 做的一局（v4，最后置入的是日神）；主菜单真点「继续」，看迁移推出来的信仰、顶端栏；再存再读一致
var out := ""
var mode := "ui"
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("F645 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/%02d_%s.png" % [out, _shots, n])


func _btn(text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).is_visible_in_tree() and (n as Button).text.strip_edges() == text: return n
	return null


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


var _pp := Vector2.ZERO
func _press_at(p_canvas: Vector2, button: int, down: bool) -> void:
	if down:
		_pp = root.get_final_transform() * p_canvas
		Input.warp_mouse(_pp)
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = down
	e.position = _pp
	e.global_position = _pp
	Input.parse_input_event(e)


func _click(b: Control) -> void:
	_mouse_at(b.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)


func _hover(c: Control) -> void:
	var p := root.get_final_transform() * c.get_global_rect().get_center()
	Input.warp_mouse(p)
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _panel() -> Node:
	for n in root.find_children("*", "", true, false):
		if n.get("board_view") != null and n.has_method("select_faith") and (n as CanvasItem).is_visible_in_tree(): return n
	return null


func _widget() -> Control:
	for n in root.find_children("*", "", true, false):
		if n is HudWidget and n.has_method("roll_value") and String(n.get_script().resource_path).ends_with("faith_widget.gd"): return n
	return null


func _charm(id: StringName) -> ItemInstance:
	for c in [_flow.run.board, _flow.run.storage]:
		for it in c.items():
			if (it as ItemInstance).def.id == id: return it
	return null


func _state(tag: String) -> void:
	var r := _flow.run
	var w := _widget()
	var ctx = r.faith_context() if r.has_method("faith_context") else null
	L("%s：选 %s；有效 %s；联系 %s；顶端栏字「%s」；徽记 %s 透明度 %.1f；底 %.1f；改信锁「%s」；信力 %s；祈愿 %s" % [tag, String(r.selected_faith), String(r.active_faith_id()), String(r.faith_connection()),
		w.text_of() if w != null else "无控件", str(w.icon.texture != null) if w != null else "-", w.icon.modulate.a if w != null else -1.0, w.self_modulate.a if w != null else -1.0, r.faith_switch_refusal(), str(r.faith_power.points_by_tag()), _prayers(r)])


func _prayers(r: RunState) -> String:
	if not r.faith_power.has_method("prayer_of"): return "（无祈愿）"
	var o := []
	for id in [&"brute", &"sun"]: o.append("%s %d/%d" % [String(id), r.faith_power.prayer_of(id), r.faith_power.prayer_cap(id)])
	return " ".join(o)


## 右键棋盘上的 [param id]，看钉住的悬浮窗里信仰键的字
func _right_click(id: StringName) -> String:
	var p := _panel()
	var inst := _charm(id)
	if p == null or inst == null or not _flow.run.board.has_item(inst.uid):
		return "（背包没开或信物不在棋盘）"
	var v: Control = p.board_view
	var rect: Rect2 = v.item_rect(inst.uid)
	_mouse_at(v.get_global_transform_with_canvas() * rect.get_center(), MOUSE_BUTTON_RIGHT)
	return "右键 %s" % String(id)


func _anchor_btn() -> Button:
	for k in ["act.anchor", "act.anchor_drop"]:
		var b := _btn(UiText.t(k))
		if b != null: return b
	return null


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 9000:
		L("超时"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	if mode == "old":
		return _old()
	if mode == "gods":
		return _gods()
	if mode == "setup":
		return _setup()
	if mode == "layout":
		return _layout()
	if mode == "ground":
		return _ground()
	if _st == 40:
		return _after_smite()
	if _st == 31:
		return _walk_to_battle()
	return _ui()


var _anchor_seq := []


func _ui() -> bool:
	var scr := _flow.screen
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
				if not (c as ChapterDef).id.begins_with("prologue"): ch = c; break
			L("跳过教程后可出的章：%s → 直开 %s" % [str(_flow.available_chapters().map(func(c): return String(c.id))), String(ch.id) if ch != null else "无"])
			if ch == null: quit(1); return true
			_flow.begin_direct(ch, 780613)
			_st = 3
		3:
			if scr == GameFlow.Screen.EVENT:
				if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
				elif _flow.run.events.pending_event() != null: _flow.choose_event(0)
				_wait = 10
				return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			var r := _flow.run
			if r.phase == RunState.Phase.PICK_SPAWN:
				var ms = _game.base()
				var ok: bool = ms.pick_spawn(r.map.entry_ids[0]) if ms != null and ms.has_method("pick_spawn") else _flow.pick_spawn(r.map.entry_ids[0])
				L("挑出生点 %d（地图屏 pick_spawn）：%s" % [r.map.entry_ids[0], str(ok)])
				_wait = 10
				return false
			for id in [&"charm_brute", &"charm_sun"]:
				var inst := ItemInstance.create(_flow.items.get_def(id), 0)
				var ok := r.board.try_add(inst)
				L("测试辅助：棋盘塞 %s：%s" % [String(id), str(ok)])
			_flow._flush()
			_state("新局、两件信物刚放上棋盘（应不奉神）")
			_key(KEY_B)
			_wait = 15
			_st = 4
		4:
			shot("bag_open_none")
			_state("开背包")
			L(_right_click(&"charm_brute"))
			_wait = 8
			_st = 5
		5:
			var b := _anchor_btn()
			shot("brute_tip_select")
			L("蛮神悬浮窗信仰键：%s%s" % [b.text if b != null else "没有", "（灰）" if b != null and b.disabled else ""])
			if b != null: _click(b)
			_wait = 10
			_st = 6
		6:
			_state("点「奉为主信仰」蛮神后")
			shot("brute_selected")
			_key(KEY_B)     # 关背包看顶端栏
			_wait = 10
			_st = 7
		7:
			var w := _widget()
			if w != null: _hover(w)
			_wait = 10
			_st = 8
		8:
			shot("hud_ok_tip")
			_key(KEY_B)
			_wait = 15
			_st = 9
		9:
			# 后放日神：挪去地上再挪回棋盘（老规则会改信）
			var r := _flow.run
			var sun := _charm(&"charm_sun")
			var a := InventoryService.transfer_auto(r.board, sun.uid, r.storage)
			var b := InventoryService.transfer_auto(r.storage, sun.uid, r.board)
			_flow._flush()
			_state("日神挪下去再放回（%s / %s，应仍是蛮神）" % [str(a), str(b)])
			L(_right_click(&"charm_sun"))
			_wait = 8
			_st = 10
		10:
			var b := _anchor_btn()
			L("日神悬浮窗信仰键：%s%s" % [b.text if b != null else "没有", "（灰）" if b != null and b.disabled else ""])
			shot("sun_tip")
			_mouse_at(Vector2(20, 500), MOUSE_BUTTON_LEFT)     # 点空处收起悬浮窗
			_wait = 10
			_st = 11
		11:
			var r := _flow.run
			var br := _charm(&"charm_brute")
			var a := InventoryService.transfer_auto(r.board, br.uid, r.storage)
			_flow._flush()
			_state("蛮神信物挪到地上（%s，应联系中断、不换日神）" % str(a))
			shot("broken_bag")
			_key(KEY_B)
			_wait = 10
			_st = 12
		12:
			var w := _widget()
			if w != null: _hover(w)
			_wait = 10
			_st = 13
		13:
			shot("hud_broken_tip")
			_key(KEY_B)
			_wait = 15
			_st = 14
		14:
			var r := _flow.run
			var br := _charm(&"charm_brute")
			L(_right_click(&"charm_brute") + "（在地上，应点不了）")
			var a := InventoryService.transfer_auto(r.storage, br.uid, r.board)
			_flow._flush()
			_state("蛮神信物挪回棋盘（%s，应恢复）" % str(a))
			_wait = 8
			_st = 15
		15:
			L(_right_click(&"charm_brute"))
			_wait = 8
			_st = 16
		16:
			var b := _anchor_btn()
			L("蛮神悬浮窗信仰键：%s%s" % [b.text if b != null else "没有", "（灰）" if b != null and b.disabled else ""])
			shot("brute_tip_drop")
			if b != null: _click(b)
			_wait = 10
			_st = 17
		17:
			_state("点「不再奉神」后")
			shot("renounced")
			Input.warp_mouse(root.get_final_transform() * Vector2(1500, 860))     # 鼠标挪开，钉住的悬浮窗自己收（它压着日神那格）
			_wait = 40
			_st = 171
		171:
			L(_right_click(&"charm_sun"))
			_wait = 8
			_st = 18
		18:
			var b := _anchor_btn()
			L("日神悬浮窗信仰键：%s" % (b.text if b != null else "没有"))
			if b != null: _click(b)
			_wait = 10
			_st = 19
		19:
			_state("奉日神后")
			shot("sun_selected")
			_key(KEY_B)
			_wait = 10
			_st = 20
		20:
			L("存档回主菜单：%s" % str(_flow.save()))
			_flow.to_main_menu()
			_wait = 30
			_st = 21
		21:
			var cb := _btn(UiText.t("menu.continue"))
			L("主菜单「继续」：%s" % ("真点" if cb != null else "没找到，continue_game"))
			if cb != null: _click(cb)
			else: _flow.continue_game()
			_wait = 40
			_st = 22
		22:
			if scr != GameFlow.Screen.MAP:
				L("继续后屏 %s" % GameFlow.Screen.keys()[scr])
				if scr == GameFlow.Screen.META and _flow.has_save(): _flow.continue_game()
				_wait = 20
				return false
			_state("读档后（应仍是日神）")
			shot("reload")
			var r := _flow.run
			r.select_faith(&"brute")
			var def: FaithDef = r.selected_faith_def()
			var p := 0
			while def != null and def.tier_of(p) < 3 and p < 5000: p += 10
			r.faith_power.add_points(&"brute", p - r.faith_power.points_of(&"brute"))
			r.faith_power.add_prayer(&"brute", 50)
			_flow._flush()
			L("测试辅助：奉蛮神，信力补到 %d（%d 阶），祈愿 +50 → %d" % [r.faith_power.points_of(&"brute"), r.faith_power.tier_of(&"brute"), r.faith_power.prayer_of(&"brute")])
			_state("蛮神三阶")
			var w := _widget()
			if w != null: _hover(w)
			_wait = 10
			_st = 30
		30:
			shot("hud_brute_t3_tip")
			_key(KEY_ESCAPE)
			_st = 31
			_wait = 5
		31:
			return _walk_to_battle()
	return false


var _steps := 0


## 往一场普通战斗走：地图上挑相邻没去过的点（战斗优先），事件挑能进战前准备的选项；到战前准备屏看秒杀键，真点耗祈愿那个
func _walk_to_battle() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	_steps += 1
	if _steps > 60:
		L("走了 60 步没碰上战前准备"); quit(1); return true
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); _wait = 5; return false
	match scr:
		GameFlow.Screen.MAP:
			var best := -1
			for n in r.travel.available_moves():
				var nd := r.map.get_node(n)
				if nd == null or nd.is_visited(): continue
				if nd.type == (&"event" if mode == "layout" and _ev_seen < 2 else &"battle"): best = n; break
				if best < 0: best = n
			if best < 0 and not r.travel.available_moves().is_empty(): best = r.travel.available_moves()[0]
			L("地图：走到 %d（%s）" % [best, String(r.map.get_node(best).type) if best >= 0 else "?"])
			_flow.step_to(best)
		GameFlow.Screen.EVENT:
			if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
			else:
				var ev: EventDef = r.events.pending_event()
				if ev == null: _flow.resume()
				else:
					var ctx = r.events._event_ctx(r.events.pending_node())
					var pick := -1
					for i in ev.options.size():
						if (ev.options[i] as EventOption).locked_reason(ctx) == "":
							if pick < 0: pick = i
							if String((ev.options[i] as EventOption).label).contains("战") or String((ev.options[i] as EventOption).label).contains("离开"): pick = i; break
					_flow.choose_event(maxi(pick, 0))
		GameFlow.Screen.SEARCH:
			_flow.close_search()
		GameFlow.Screen.LOOT:
			_flow.take_all_loot(); _flow.resume()
		GameFlow.Screen.PREBATTLE:
			var pv0 := r.faith_power.prayer_of(&"brute")
			var dv0 := r.faith_power.points_of(&"brute")
			var vt0 := r.vitality.current
			var keys := []
			var pray: Button = null
			for n in root.find_children("*", "Button", true, false):
				var t := (n as Button).text
				if (n as Button).is_visible_in_tree() and (t.contains("祈愿") or t.contains("Prayer") or t.contains("体力") or t.contains("Vitality")) and t.length() < 40:
					keys.append(t + ("（灰）" if (n as Button).disabled else ""))
					if (t.contains("祈愿") or t.contains("Prayer")) and not (n as Button).disabled: pray = n
			L("战前准备：秒杀相关键 %s；祈愿 %d 信力 %d 体力 %d" % [str(keys), pv0, dv0, vt0])
			shot("prebattle_smite")
			if pray == null:
				L("没有可点的祈愿秒杀键"); quit(0); return true
			_click(pray)
			_st = 40
			_wait = 20
			_pv = pv0; _dv = dv0; _vt = vt0
			return false
		GameFlow.Screen.BATTLE, GameFlow.Screen.RESULT, GameFlow.Screen.RANSOM:
			L("走路中碰到屏 %s，结束" % GameFlow.Screen.keys()[scr]); quit(0); return true
	_wait = 10
	return false


var _pv := 0
var _dv := 0
var _vt := 0


func _after_smite() -> bool:
	var r := _flow.run
	L("点完祈愿秒杀：屏 %s；祈愿 %d → %d；信力 %d → %d；阶 %d；体力 %d → %d" % [GameFlow.Screen.keys()[_flow.screen], _pv, r.faith_power.prayer_of(&"brute"), _dv, r.faith_power.points_of(&"brute"), r.faith_power.tier_of(&"brute"), _vt, r.vitality.current])
	shot("after_smite")
	quit(0)
	return true
	return false


func _old() -> bool:
	var scr := _flow.screen
	match _st:
		0:
			if _f < 60: return false
			L("主菜单：有一局存档 %s" % str(_flow.has_save()))
			var cb := _btn(UiText.t("menu.continue"))
			if cb != null: _click(cb)
			else: _flow.continue_game()
			_wait = 40
			_st = 1
		1:
			if scr != GameFlow.Screen.MAP:
				L("屏 %s" % GameFlow.Screen.keys()[scr])
				if scr == GameFlow.Screen.META and _flow.has_save(): _flow.continue_game()
				_wait = 20
				if _f > 1500: quit(1); return true
				return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			var r := _flow.run
			var ids := []
			for it in r.board.items():
				if (it as ItemInstance).def.is_anchor(): ids.append("%s#%d(seq %d)" % [String((it as ItemInstance).def.id), (it as ItemInstance).uid, (it as ItemInstance).placed_seq])
			L("旧档读进来：版本 → 章 %s；棋盘信物 %s" % [String(r.chapter.id), str(ids)])
			_state("旧档迁移后")
			shot("old_loaded")
			var w := _widget()
			if w != null: _hover(w)
			_wait = 10
			_st = 2
		2:
			shot("old_hud_tip")
			L("再存：%s" % str(_flow.save()))
			var txt := FileAccess.get_file_as_string(_flow.save_path)
			var d = JSON.parse_string(txt)
			L("存档文件 %s：version %s；faith_selection %s" % [_flow.save_path, str(d.get("version")) if d is Dictionary else "?", str(d.get("faith_selection")) if d is Dictionary else "?"])
			_flow.to_main_menu()
			_wait = 30
			_st = 3
		3:
			_flow.continue_game()
			_wait = 40
			_st = 4
		4:
			if scr != GameFlow.Screen.MAP:
				_wait = 10
				return false
			_state("再读一次")
			quit(0)
			return true
	return false


## gods：一局里六位神轮流奉（真点按钮），每位补到三阶（测试辅助），打一场普通战斗，看 buff 栏、战记、战后信力与祈愿、last_mechanic
const GODS := [&"skill", &"hunt", &"earth", &"brute", &"sun", &"nature"]
var _gi := 0
var _gs := 0
var _gd0 := 0
var _gp0 := 0
var _bf := 0


func _gods() -> bool:
	var scr := _flow.screen
	if _st < 4:
		match _st:
			0:
				if _f < 60: return false
				_flow.start_new_game()
				_st = 1
			1:
				var b = _game.base()
				if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
					b.decline_tutorial(); _wait = 20; _st = 2
				elif _f > 240:
					_flow.decline_tutorial(); _wait = 20; _st = 2
			2:
				var ch: ChapterDef = null
				for c in _flow.available_chapters():
					if not (c as ChapterDef).id.begins_with("prologue"): ch = c; break
				_flow.begin_direct(ch, 780613)
				_st = 3
			3:
				if scr == GameFlow.Screen.EVENT:
					if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
					elif _flow.run.events.pending_event() != null: _flow.choose_event(0)
					_wait = 10
					return false
				if scr != GameFlow.Screen.MAP: return false
				for c in root.find_children("*", "CoachOverlay", true, false):
					(c as CoachOverlay).next(); _wait = 5; return false
				var r := _flow.run
				if r.phase == RunState.Phase.PICK_SPAWN:
					var ms = _game.base()
					ms.pick_spawn(r.map.entry_ids[0]); _wait = 10; return false
				for g in GODS:
					r.board.try_add(ItemInstance.create(_flow.items.get_def(StringName("charm_" + String(g))), 0))
				for wid in [&"knife", &"club", &"round_shield"]:
					L("测试辅助：放 %s → %s" % [String(wid), str(r.board.try_add(ItemInstance.create(_flow.items.get_def(wid), 0)))])
				_flow._flush()
				L("测试辅助：六件信物放上棋盘；棋盘 %s" % str(r.board.items().map(func(i): return String((i as ItemInstance).def.id))))
				_st = 4
		return false
	if _gi >= GODS.size():
		return _result_page()
	var g: StringName = GODS[_gi]
	var r := _flow.run
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); _wait = 5; return false
	match _gs:
		0:
			if scr != GameFlow.Screen.MAP:
				return _walk_step()
			Input.warp_mouse(root.get_final_transform() * Vector2(1500, 860))
			var ms0 = _game.base()
			if ms0 != null and ms0.get("_bag") != null: L("[%s] 背包本来就开着" % String(GODS[_gi]))
			else: _key(KEY_B)
			_wait = 40; _gs = 1
		1:
			for n in root.find_children("*", "HoverTip", true, false): n.hide_tip()
			_wait = 5; _gs = 9
		9:
			L(_right_click(StringName("charm_" + String(g)))); _wait = 8; _gs = 2
		2:
			var b := _btn(UiText.t("act.anchor"))
			shot("%s_tip" % String(g))
			L("[%s] 悬浮窗信仰键：%s" % [String(g), b.text if b != null else "没有（可能已是主信仰）"])
			if b != null: _click(b)
			elif r.selected_faith != g:
				var why: String = r.select_faith(g)
				L("[%s] 真点没找到键（信物被别的东西挡住），测试辅助直接 select_faith：「%s」" % [String(g), why])
			_wait = 10; _gs = 3
		3:
			_key(KEY_B); _wait = 10; _gs = 4
		4:
			var def: FaithDef = r.selected_faith_def()
			var p := r.faith_power.points_of(g)
			while def != null and def.tier_of(p) < 3 and p < 5000: p += 5
			r.faith_power.add_points(g, p - r.faith_power.points_of(g))
			r.vitality.current = r.vitality.maximum
			_flow._flush()
			_state("[%s] 奉神并补到三阶（测试辅助），体力补满" % String(g))
			var w := _widget()
			if w != null: _hover(w)
			_wait = 10; _gs = 5
		5:
			shot("%s_hud_tip" % String(g))
			Input.warp_mouse(root.get_final_transform() * Vector2(1500, 860))
			_wait = 10; _gs = 6; _steps = 0
		6:
			if scr == GameFlow.Screen.PREBATTLE:
				_gd0 = r.faith_power.points_of(g); _gp0 = r.faith_power.prayer_of(g)
				var pre = _game.overlay()
				shot("%s_prebattle" % String(g))
				L("[%s] 开战（信力 %d，祈愿 %d）" % [String(g), _gd0, _gp0])
				if pre != null and pre.has_method("start_battle"): pre.start_battle()
				else: _flow.start_battle()
				_bf = 0; _gs = 7; _wait = 10
				return false
			return _walk_step()
		7:
			if scr != GameFlow.Screen.BATTLE: return false
			var bs = _game.overlay()
			_bf += 1
			if _bf == 120:
				shot("%s_battle_mid" % String(g))
				var v: BattleView = bs.view()
				L("[%s] 回放 %.1f 秒处截图" % [String(g), v.now()])
				v.skip_to_end()
			if bs.has_method("verdict_shown") and bs.verdict_shown():
				var v2: BattleView = bs.view()
				if not v2.log_open: v2.set_log_open(true)
				var fl := []
				var all: Array = v2.log_lines()
				for ln in all:
					var t := BattleNarrator.plain(ln)
					if FAITH_WORDS.any(func(w): return t.contains(w)): fl.append(t)
				L("[%s] 战记 %d 行，信仰相关 %d 行：%s" % [String(g), all.size(), fl.size(), " | ".join(fl.slice(0, 8))])
				shot("%s_battle_end" % String(g))
				bs.proceed()
				_wait = 20; _gs = 8
		8:
			if scr == GameFlow.Screen.BATTLE: return false
			L("[%s] 战后：屏 %s；信力 %d → %d；祈愿 %d → %d；last_mechanic %s；体力 %d" % [String(g), GameFlow.Screen.keys()[scr], _gd0, r.faith_power.points_of(g), _gp0, r.faith_power.prayer_of(g), str(r.last_mechanic), r.vitality.current])
			_gi += 1; _gs = 0
	return false


## 往战斗走一步（地图挑战斗、事件挑能打的、搜索关、战利品全拿）
var _rs := 0
const FAITH_WORDS := ["自然之力", "draws on Nature", "Finesse", "连携", "combo", "盯上", "marked the foe", "拆掉", "拆到", "took apart", "broke the foe", "Supported", "加时", "Overtime", "信仰", "Faith", "巧劲", "Momentum", "拆解", "Dismantl", "承托", "Support", "怒气", "Rage", "烈日", "Blazing", "生息", "Regrowth", "守护", "不屈", "Undying"]


## 六神走完：测试辅助直接记成撤离（force_extract），看结果页
func _result_page() -> bool:
	var scr := _flow.screen
	match _rs:
		0:
			if scr != GameFlow.Screen.MAP: return _walk_step()
			L("六位神走完；测试辅助 force_extract → %s" % str(_flow.run.force_extract()))
			_flow._flush(); _wait = 60; _rs = 1
		1:
			L("结果页：屏 %s" % GameFlow.Screen.keys()[scr])
			var res = _flow.last_payload.get("result")
			if res != null: L("结果：faith_top %s；faith_pace「%s」" % [str(res.faith_top), res.faith_pace])
			var txt := []
			for n in root.find_children("*", "Label", true, false):
				if (n as Label).is_visible_in_tree() and (n as Label).text.strip_edges() != "": txt.append((n as Label).text.strip_edges().replace("\n", " "))
			L("结果页字：%s" % " / ".join(txt.slice(0, 40)))
			shot("result_page")
			_rs = 2; _wait = 10
		2:
			for b in root.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree() and (b as Button).text.strip_edges() != "": L("结果页键「%s」" % (b as Button).text.strip_edges())
			shot("result_page_2")
			quit(0); return true
	return false


func _walk_step() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	_steps += 1
	if _steps > (250 if mode == "layout" else 80):
		L("走了 80 步没碰上战斗"); quit(1); return true
	match scr:
		GameFlow.Screen.MAP:
			if r.is_over(): L("这一局结束了"); quit(1); return true
			var best := -1
			for n in r.travel.available_moves():
				var nd := r.map.get_node(n)
				if nd == null or nd.is_visited(): continue
				if nd.type == (&"event" if mode == "layout" and _ev_seen < 2 else &"battle"): best = n; break
				if best < 0: best = n
			if best < 0 and not r.travel.available_moves().is_empty(): best = r.travel.available_moves()[randi() % r.travel.available_moves().size()]
			_flow.step_to(best)
		GameFlow.Screen.EVENT:
			if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
			else:
				var ev: EventDef = r.events.pending_event()
				if ev == null: _flow.resume()
				else:
					var ctx = r.events._event_ctx(r.events.pending_node())
					var pick := -1
					for i in ev.options.size():
						if (ev.options[i] as EventOption).locked_reason(ctx) == "":
							if pick < 0: pick = i
							var lb := String((ev.options[i] as EventOption).label)
							if lb.contains("战") or lb.contains("离开"): pick = i; break
					_flow.choose_event(maxi(pick, 0))
		GameFlow.Screen.SEARCH:
			_flow.close_search()
		GameFlow.Screen.LOOT:
			_flow.take_all_loot(); _flow.resume()
		GameFlow.Screen.ALTAR:
			_flow.close_altar()
		GameFlow.Screen.SHOP, GameFlow.Screen.FORGE:
			_flow.resume()
		GameFlow.Screen.RANSOM:
			_flow.refuse_ransom()
		_:
			if scr != GameFlow.Screen.PREBATTLE and scr != GameFlow.Screen.BATTLE:
				_flow.resume()
	_wait = 10
	return false


## setup：开局屏（不走教程）上显式选神 —— 仓库塞蛮神、日神（测试辅助）→ 置入初始包 → 右键蛮神真点「奉为主信仰」→ 出发；看地图上的顶端栏
var _sp: Node = null
func _setup() -> bool:
	var scr := _flow.screen
	match _st:
		0:
			if _f < 60: return false
			_flow.start_new_game(); _st = 1
		1:
			var b = _game.base()
			if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
				b.decline_tutorial(); _wait = 20; _st = 2
			elif _f > 240:
				_flow.decline_tutorial(); _wait = 20; _st = 2
		2:
			_flow.new_run(); _wait = 30; _st = 3
		3:
			L("新局：屏 %s" % GameFlow.Screen.keys()[scr])
			for n in root.find_children("*", "", true, false):
				if n.has_method("carry_in") and n.has_method("chosen_faith"): _sp = n
			if _sp == null: L("开局屏没找到"); quit(1); return true
			_sp.show_page(1); _wait = 40; _st = 30
		30:
			for id in [&"charm_brute", &"charm_sun"]:
				var inst := ItemInstance.create(_flow.items.get_def(id), 0)
				_flow.meta.warehouse.try_add(inst)
				_sp.carry_in(inst.uid)
			L("测试辅助：仓库塞蛮神、日神并置入初始包；开局屏选 %s" % ("「%s」" % String(_sp.chosen_faith())))
			_wait = 20; _st = 4
		4:
			shot("setup_board")
			var v: Control = _sp.get("_board_view")
			var uid := -1
			for it in _sp.board.items():
				if (it as ItemInstance).def.id == &"charm_brute": uid = (it as ItemInstance).uid
			L("初始包：%s；蛮神 uid %d；视图 %s" % [str(_sp.board.items().map(func(i): return "%s#%d" % [String((i as ItemInstance).def.id), (i as ItemInstance).uid])), uid, str(v)])
			if v == null or uid < 0: L("初始包里没有蛮神信物"); quit(1); return true
			L("视图 global_position %s 缩放 %s" % [str(v.global_position), str(v.get_global_transform_with_canvas().get_scale())])
			L("蛮神格 %s → 画布 %s" % [str(v.item_rect(uid)), str(v.get_global_transform_with_canvas() * (v.item_rect(uid) as Rect2).get_center())])
			_press_at(v.get_global_transform_with_canvas() * (v.item_rect(uid) as Rect2).get_center(), MOUSE_BUTTON_RIGHT, true)
			_wait = 10; _st = 41
		41:
			L("右键按下（未松）后：蛮神在棋盘 %s" % str(_sp.board.items().any(func(i): return (i as ItemInstance).def.id == &"charm_brute")))
			shot("setup_rpress")
			_press_at(Vector2.ZERO, MOUSE_BUTTON_RIGHT, false)
			_wait = 10; _st = 42
		42:
			for it in _flow.meta.warehouse.items():
				if (it as ItemInstance).def.id == &"charm_brute":
					L("蛮神信物放回初始包（测试辅助）：%s" % str(_sp.carry_in((it as ItemInstance).uid))); break
			_wait = 20; _st = 43
		43:
			var v: Control = _sp.get("_board_view")
			for it in _sp.board.items():
				if (it as ItemInstance).def.id == &"charm_brute":
					var p := root.get_final_transform() * (v.get_global_transform_with_canvas() * (v.item_rect((it as ItemInstance).uid) as Rect2).get_center())
					for k in 3:
						Input.warp_mouse(p + Vector2(k, 0))
						var e := InputEventMouseMotion.new()
						e.position = p + Vector2(k, 0); e.global_position = e.position
						Input.parse_input_event(e)
			L("改用悬停：鼠标停在蛮神信物上等两秒")
			_wait = 130; _st = 5
		5:
			var b := _btn(UiText.t("act.anchor"))
			L("右键后初始包：%s；仓库有蛮神 %s" % [str(_sp.board.items().map(func(i): return "%s@%s" % [String((i as ItemInstance).def.id), str((i as ItemInstance).origin)])), str(_flow.meta.warehouse.items().any(func(i): return (i as ItemInstance).def.id == &"charm_brute"))])
			shot("setup_tip")
			L("开局屏悬浮窗信仰键：%s" % (b.text if b != null else "没有"))
			if b != null: _click(b)
			_wait = 10; _st = 6
		6:
			L("开局屏点完：选 「%s」" % String(_sp.chosen_faith()))
			Input.warp_mouse(root.get_final_transform() * Vector2(1500, 860))
			_wait = 30; _st = 7
		7:
			shot("setup_chosen")
			L("出发：%s" % str(_sp.depart())); _wait = 30; _st = 8
		8:
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 20; return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			_wait = 30; _st = 9
		9:
			_state("开局后（地图）")
			shot("setup_map_hud")
			quit(0); return true
	return false


## layout（v6.50 报告 334）：地图悬停行动代价、日晷刻数与设置、图例收合、腰带全空变淡、背包三种查看、暂停菜单「最近记录」、
## 全部拾取部分成功、无图事件紧凑版。能真点的都真点（鼠标、键盘）
var _ls := 0
var _ev_seen := 0
var _loot_done := false
func _ms() -> Node:
	return _game.base()


func _text_btn(t: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).is_visible_in_tree() and (n as Button).text.strip_edges() == t: return n
	return null


func _layout() -> bool:
	var scr := _flow.screen
	if _st < 4:
		match _st:
			0:
				if _f < 60: return false
				_flow.start_new_game(); _st = 1
			1:
				var b = _game.base()
				if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
					b.decline_tutorial(); _wait = 20; _st = 2
				elif _f > 240:
					_flow.decline_tutorial(); _wait = 20; _st = 2
			2:
				var ch: ChapterDef = null
				for c in _flow.available_chapters():
					if not (c as ChapterDef).id.begins_with("prologue"): ch = c; break
				_flow.begin_direct(ch, 780613); _st = 3
			3:
				if scr == GameFlow.Screen.EVENT:
					if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
					elif _flow.run.events.pending_event() != null: _flow.choose_event(0)
					_wait = 10; return false
				if scr != GameFlow.Screen.MAP: return false
				for c in root.find_children("*", "CoachOverlay", true, false):
					(c as CoachOverlay).next(); _wait = 5; return false
				if _flow.run.phase == RunState.Phase.PICK_SPAWN:
					_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
				for wid in [&"knife", &"round_shield"]:
					L("测试辅助：放 %s → %s" % [String(wid), str(_flow.run.board.try_add(ItemInstance.create(_flow.items.get_def(wid), 0)))])
				_flow._flush()
				_wait = 30; _st = 4
		return false
	var r := _flow.run
	var ms := _ms()
	var host: HudHost = ms.hud() if ms != null and ms.has_method("hud") else null
	match _ls:
		0:
			var lg = host.widget(&"legend"); var bl = host.widget(&"belt"); var cd = host.widget(&"countdown")
			L("地图：图例展开 %s（设置 legend_open %s）；腰带全空 %s 透明度 %.2f；日晷档 %s 刻数 %s（设置始终 %s）" % [str(lg.expanded()), str(_flow.settings.legend_open), str(bl.slots.all_empty()), bl.slots.modulate.a, str(cd.stage()), str(cd.shows_number()), str(_flow.settings.dial_number_always)])
			shot("map")
			var tgt: int = r.travel.available_moves()[0]
			var v: MapView = ms._view
			var gp := v.get_global_transform() * v.to_screen(v.positions().get(tgt, Vector2.ZERO))
			for k in 3:
				var p := root.get_final_transform() * (gp + Vector2(k, 0))
				Input.warp_mouse(p)
				var e := InputEventMouseMotion.new(); e.position = p; e.global_position = p
				Input.parse_input_event(e)
			_wait = 40; _ls = 1
		1:
			L("真悬停隔壁点：浮窗「%s」" % Glossary.strip_bbcode(ms.tooltip_text()).replace("\n", " / "))
			if ms.tooltip_text() == "":
				ms._on_node_hovered(r.travel.available_moves()[0])
				L("（真悬停没出浮窗，改直接调 _on_node_hovered）浮窗「%s」" % Glossary.strip_bbcode(ms.tooltip_text()).replace("\n", " / "))
			shot("map_hover")
			Input.warp_mouse(root.get_final_transform() * Vector2(800, 880))
			_wait = 10; _ls = 2
		2:
			var lg: Control = host.widget(&"legend")
			L("图例收起时悬浮字「%s」" % lg.tooltip_text.replace("\n", " / "))
			_click(lg); _wait = 20; _ls = 3
		3:
			var lg = host.widget(&"legend")
			L("真点图例后：展开 %s；设置 legend_open %s" % [str(lg.expanded()), str(_flow.settings.legend_open)])
			shot("legend_open")
			_click(lg); _wait = 20; _ls = 4
		4:
			var lg = host.widget(&"legend")
			L("再点：展开 %s；设置 %s" % [str(lg.expanded()), str(_flow.settings.legend_open)])
			var cd = host.widget(&"countdown")
			var lim := CountdownModule.of(r).limit() if CountdownModule.of(r) != null else -1
			if lim > 0:
				r.travel.clock.total = maxi(0, lim - 3); _flow._flush()
			_wait = 20; _ls = 5
		5:
			var cd = host.widget(&"countdown")
			L("测试辅助：倒计时拨到剩 3 → 档 %s 刻数 %s" % [str(cd.stage()), str(cd.shows_number())])
			shot("dial_low")
			r.travel.clock.total = 0
			_flow.settings.dial_number_always = true; _flow._flush()
			_wait = 20; _ls = 6
		6:
			var cd = host.widget(&"countdown")
			L("设置「始终显示」：剩得多 档 %s 刻数 %s" % [str(cd.stage()), str(cd.shows_number())])
			shot("dial_always")
			_flow.settings.dial_number_always = false
			Input.warp_mouse(root.get_final_transform() * Vector2(1500, 860))
			_key(KEY_B); _wait = 40; _ls = 7
		7:
			var win = ms._bag.get_child(0) if ms._bag != null and ms._bag.get_child_count() > 0 else null
			for it in r.board.items():
				if ItemErosion.eligible(it): ItemErosion.add(it); ItemErosion.add(it); L("测试辅助：%s 侵蚀两层" % Names.of((it as ItemInstance).def)); break
			_wait = 5; _ls = 8
		8:
			var b := _text_btn(UiText.t("inv.view_links"))
			L("背包查看签：普通 %s 联动 %s 风险 %s" % [str(_text_btn(UiText.t("inv.view_normal")) != null), str(b != null), str(_text_btn(UiText.t("inv.view_risk")) != null)])
			if b != null: _click(b)
			_wait = 20; _ls = 9
		9:
			L("真点联动：%s" % str(ms._bag.get_child(0).view_mode()))
			shot("bag_links")
			var b := _text_btn(UiText.t("inv.view_risk"))
			if b != null: _click(b)
			_wait = 20; _ls = 10
		10:
			L("真点风险：%s" % str(ms._bag.get_child(0).view_mode()))
			shot("bag_risk")
			var b := _text_btn(UiText.t("inv.view_normal"))
			if b != null: _click(b)
			_wait = 20; _ls = 11
		11:
			L("真点普通：%s" % str(ms._bag.get_child(0).view_mode()))
			_key(KEY_B); _wait = 20; _ls = 12
		12:
			L("最近记录（关背包后）：%d 条" % NoticeLayer.history().size())
			_key(KEY_ESCAPE); _wait = 20; _ls = 13
		13:
			var b := _text_btn(UiText.t("map.pause_recent"))
			L("Esc 暂停书：「最近记录」键 %s" % ("在" if b != null else "不在"))
			shot("pause")
			if b != null: _click(b)
			_wait = 20; _ls = 14
		14:
			L("最近记录开着 %s；前几条：%s" % [str(ms.recent_open()), str(NoticeLayer.history().slice(0, 5).map(func(d): return String(d.get("text", "")).left(40)))])
			shot("recent")
			_key(KEY_ESCAPE); _wait = 15; _ls = 15
		15:
			L("Esc 一下：最近记录开着 %s；暂停书在 %s" % [str(ms.recent_open()), str(ms._pause != null)])
			_key(KEY_ESCAPE); _wait = 15; _ls = 16; _steps = 0
		16:
			return _layout_walk()
	return false


## 往前走：碰到事件截图（看有没有图），碰到战利品就测「全部拾取」放不下的情形
func _layout_walk() -> bool:
	var scr := _flow.screen
	var r := _flow.run
	if _ev_seen >= 2 and _loot_done and not _pend_take and not _pend_shot:
		L("布局走查完"); quit(0); return true
	if scr == GameFlow.Screen.EVENT and not bool(_flow.last_payload.get("briefing", false)) and r.events.pending_event() != null and _ev_seen < 2 and _wait == 0 and not _ev_shot.has(r.events.pending_node().id):
		var ev: EventDef = r.events.pending_event()
		_ev_shot[r.events.pending_node().id] = true
		_ev_seen += 1
		L("事件 %s：有图 %s" % [String(ev.id), str(ev.image != "")])
		shot("event_%d" % _ev_seen)
		_wait = 5
		return false
	if scr == GameFlow.Screen.LOOT and not _loot_done:
		_loot_done = true
		var fill: ItemDef = _flow.items.get_def(&"bone_dice")
		var n := 0
		while n < 300 and fill != null and r.board.try_add(ItemInstance.create(fill, 0)): n += 1
		_flow._flush()
		L("测试辅助：背包塞满 %d 件骨骰" % n)
		_wait = 20
		_pend_take = true
		return false
	if _pend_take:
		_pend_take = false
		var b: Control = _text_btn(UiText.t("loot.take_all"))
		if b == null:
			for n in root.find_children("*", "BaseButton", true, false):
				if (n as Control).is_visible_in_tree() and (n as Control).tooltip_text.begins_with(UiText.t("loot.take_all")): b = n; break
		L("战利品屏「全部拾取」键 %s" % ("在" if b != null else "不在"))
		if b != null: _click(b)
		_wait = 20; _pend_shot = true
		return false
	if _pend_shot:
		_pend_shot = false
		var h := NoticeLayer.history()
		L("全部拾取后告示：%s" % (String(h[0].get("text", "")) if not h.is_empty() else "无"))
		shot("loot_partial")
		_flow.resume(); _wait = 10
		return false
	if scr == GameFlow.Screen.PREBATTLE:
		var pre = _game.overlay()
		if pre != null and pre.has_method("start_battle"): pre.start_battle()
		else: _flow.start_battle()
		_wait = 20; return false
	if scr == GameFlow.Screen.BATTLE:
		var bs = _game.overlay()
		if bs != null and bs.has_method("view") and bs.view() != null: bs.view().skip_to_end()
		if bs != null and bs.has_method("verdict_shown") and bs.verdict_shown(): bs.proceed()
		_wait = 20; return false
	return _walk_step()
var _ev_shot := {}
var _pend_take := false
var _pend_shot := false


## ground（v6.54 PR #677）：离开节点时地上还有东西的提醒 —— 真点地图节点、真点「先收拾 / 不再提醒 / 走」，设置页真点开关
var _gr := 0
var _from := -1
func _drop_on_ground() -> void:
	var r := _flow.run
	var ok: bool = r.storage.insert(ItemInstance.create(_flow.items.get_def(&"bone_dice"), 0))
	_flow._flush()
	L("测试辅助：脚下 %d 号点地上放一副骨骰 → %s（地上 %d 件）" % [r.travel.current_id, str(ok), r.storage.item_count()])


func _click_node(id: int) -> void:
	var ms := _ms()
	var v: MapView = ms._view
	var gp := v.get_global_transform() * v.to_screen(v.positions().get(id, Vector2.ZERO))
	_mouse_at(gp, MOUSE_BUTTON_LEFT)


func _ground_next() -> int:
	var r := _flow.run
	for n in r.travel.available_moves():
		var nd := r.map.get_node(n)
		if nd != null and not nd.is_visited() and nd.type in [&"search", &"rest", &"shop", &"event", &"random"]: return n
	return r.travel.available_moves()[0]


func _ground() -> bool:
	var scr := _flow.screen
	if _st < 4:
		match _st:
			0:
				if _f < 60: return false
				_flow.start_new_game(); _st = 1
			1:
				var b = _game.base()
				if b != null and b.has_method("tutorial_ask_open") and b.tutorial_ask_open():
					b.decline_tutorial(); _wait = 20; _st = 2
				elif _f > 240:
					_flow.decline_tutorial(); _wait = 20; _st = 2
			2:
				var ch: ChapterDef = null
				for c in _flow.available_chapters():
					if not (c as ChapterDef).id.begins_with("prologue"): ch = c; break
				_flow.begin_direct(ch, 780613); _st = 3
			3:
				if scr == GameFlow.Screen.EVENT:
					if bool(_flow.last_payload.get("briefing", false)): _flow.close_briefing()
					elif _flow.run.events.pending_event() != null: _flow.choose_event(0)
					_wait = 10; return false
				if scr != GameFlow.Screen.MAP: return false
				for c in root.find_children("*", "CoachOverlay", true, false):
					(c as CoachOverlay).next(); _wait = 5; return false
				if _flow.run.phase == RunState.Phase.PICK_SPAWN:
					_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
				_wait = 30; _st = 4
		return false
	var r := _flow.run
	var ms := _ms()
	match _gr:
		0:
			L("设置 leave_ground_warn 默认 %s" % str(_flow.settings.leave_ground_warn))
			_drop_on_ground()
			_from = r.travel.current_id
			_click_node(_ground_next()); _wait = 20; _gr = 1
		1:
			if not ms.ground_warn_open():
				L("真点地图节点没弹（屏 %s，点 %d → %d），改直接调 _on_node_pressed" % [GameFlow.Screen.keys()[scr], _from, r.travel.current_id])
				ms._on_node_pressed(_ground_next(), MOUSE_BUTTON_LEFT, false); _wait = 20
			_gr = 2
		2:
			var txt := []
			for n in ms._confirm.find_children("*", "Label", true, false): txt.append((n as Label).text.strip_edges().replace("\n", " "))
			for n in ms._confirm.find_children("*", "Button", true, false): txt.append("[%s]" % (n as Button).text.strip_edges())
			L("点隔壁：提醒窗开着 %s；还在 %d 号点（应 = %d）；窗里：%s" % [str(ms.ground_warn_open()), r.travel.current_id, _from, " / ".join(txt)])
			shot("ground_warn")
			var b := _text_btn(UiText.t("map.ground_stay"))
			if b != null: _click(b)
			_wait = 20; _gr = 3
		3:
			L("真点「先收拾」：窗开着 %s；还在 %d 号点（应 = %d）；地上 %d 件" % [str(ms.ground_warn_open()), r.travel.current_id, _from, r.storage.item_count()])
			_click_node(_ground_next()); _wait = 20; _gr = 4
		4:
			if not ms.ground_warn_open(): ms._on_node_pressed(_ground_next(), MOUSE_BUTTON_LEFT, false); _wait = 20; return false
			var nv := _text_btn(UiText.t("map.ground_never"))
			if nv != null: _click(nv)
			_wait = 10; _gr = 5
		5:
			var nv := _text_btn(UiText.t("map.ground_never"))
			L("真点「不再提醒」：勾上 %s" % str(nv.button_pressed if nv != null else "无键"))
			shot("ground_never_ticked")
			var b := _text_btn(UiText.t("map.ground_go"))
			if b != null: _click(b)
			_wait = 40; _gr = 6
		6:
			if scr != GameFlow.Screen.MAP: return _walk_step()
			var f := FileAccess.get_file_as_string("user://settings.json")
			var d = JSON.parse_string(f) if f != "" else {}
			L("真点「走」：现在 %d 号点（从 %d 走开 %s）；设置 leave_ground_warn %s；settings.json 里 %s" % [r.travel.current_id, _from, str(r.travel.current_id != _from), str(_flow.settings.leave_ground_warn), str(d.get("leave_ground_warn", "没有") if d is Dictionary else "读不出")])
			_drop_on_ground()
			_from = r.travel.current_id
			_click_node(_ground_next()); _wait = 40; _gr = 7
		7:
			L("关了提醒再点隔壁：提醒窗 %s；从 %d 走到 %d" % [str(ms.ground_warn_open()), _from, r.travel.current_id])
			if ms.ground_warn_open(): ms.cancel_extract()
			_gr = 8; _steps = 0
		8:
			if scr != GameFlow.Screen.MAP: return _walk_step()
			_key(KEY_ESCAPE); _wait = 20; _gr = 9
		9:
			var b := _text_btn(UiText.t("map.pause_settings"))
			L("暂停书「设置」键 %s" % ("在" if b != null else "不在"))
			if b != null: _click(b)
			_wait = 30; _gr = 10
		10:
			var gb: Button = null
			var pre := UiText.t("settings.ground_warn_state").split("%")[0]
			for n in root.find_children("*", "Button", true, false):
				if (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(pre): gb = n
			L("设置页开关：%s" % (gb.text if gb != null else "没找到（前缀「%s」）" % pre))
			shot("settings_off")
			if gb != null: _click(gb)
			_wait = 20; _gr = 11
		11:
			var gb: Button = null
			var pre := UiText.t("settings.ground_warn_state").split("%")[0]
			for n in root.find_children("*", "Button", true, false):
				if (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(pre): gb = n
			var f := FileAccess.get_file_as_string("user://settings.json")
			var d = JSON.parse_string(f) if f != "" else {}
			L("真点设置开关后：%s；设置 %s；settings.json %s" % [gb.text if gb != null else "-", str(_flow.settings.leave_ground_warn), str(d.get("leave_ground_warn", "没有") if d is Dictionary else "读不出")])
			shot("settings_on")
			_key(KEY_ESCAPE); _wait = 30; _gr = 12
		12:
			if scr != GameFlow.Screen.MAP:
				L("Esc 后屏 %s" % GameFlow.Screen.keys()[scr]); _key(KEY_ESCAPE); _wait = 30; return false
			if ms._pause != null: _key(KEY_ESCAPE); _wait = 20; return false
			_drop_on_ground()
			_from = r.travel.current_id
			_click_node(_ground_next()); _wait = 20; _gr = 13
		13:
			if not ms.ground_warn_open(): ms._on_node_pressed(_ground_next(), MOUSE_BUTTON_LEFT, false); _wait = 20
			_gr = 14
		14:
			L("设置里重新打开后点隔壁：提醒窗 %s" % str(ms.ground_warn_open()))
			shot("ground_warn_again")
			var b := _text_btn(UiText.t("map.ground_go"))
			if b != null: _click(b)
			_wait = 40; _gr = 15
		15:
			if scr != GameFlow.Screen.MAP: return _walk_step()
			L("不勾直接「走」：从 %d 到 %d；设置仍 %s" % [_from, r.travel.current_id, str(_flow.settings.leave_ground_warn)])
			_from = r.travel.current_id
			_click_node(_ground_next()); _wait = 20; _gr = 16
		16:
			L("这个点地上空着（%d 件）再点隔壁：提醒窗 %s；从 %d 到 %d" % [r.storage.item_count(), str(ms.ground_warn_open()), _from, r.travel.current_id])
			shot("ground_empty_go")
			_gr = 17; _wait = 10
		17:
			if scr != GameFlow.Screen.MAP: return _walk_step()
			_drop_on_ground()
			var ex: MapNode = null
			for id in r.map.node_ids():
				if NodeEvents.effective_type(r.map.get_node(id)) == &"extract" and r.events.extract_fee(r.map.get_node(id)) > 0: ex = r.map.get_node(id); break
			if ex == null: ex = r.current_node()
			ms._open_confirm(ex)
			L("测试辅助：直接开撤离确认窗（按 %d 号撤离点算撤离费 %d）" % [ex.id, r.events.extract_fee(ex)])
			_wait = 20; _gr = 18
		18:
			var txt := []
			for n in ms._confirm.find_children("*", "Label", true, false): txt.append((n as Label).text.strip_edges().replace("\n", " "))
			L("撤离确认窗字：%s" % " / ".join(txt))
			shot("extract_confirm")
			ms.cancel_extract(); _wait = 10; _gr = 19
		19:
			_click_node(_ground_next()); _wait = 20; _gr = 20
		20:
			if not ms.ground_warn_open(): ms._on_node_pressed(_ground_next(), MOUSE_BUTTON_LEFT, false); _wait = 20; return false
			shot("ground_warn_coin")
			L("地上提醒走查完"); quit(0); return true
	return false
