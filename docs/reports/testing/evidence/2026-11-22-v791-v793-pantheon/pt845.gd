extends SceneTree
## 游戏测试 v7.92（PR #845，报告 384）：万神院第一批。参数 <outdir>
## 新档拒教程 → 看万神院在不在、后勤有没有那一页 → 真点【开始探索】（应直接进开局屏，没有选神）→ 开局看这一局有没有信仰、图上有没有无名祭坛、背包里有没有信物 →
## 真走一步再撤离（测试辅助 force_extract），结算屏【继续】回营地；连做三次 → 第 3 次回营地看「牌子亮起」到来通知、点【知道了】→ 后勤「万神院」页 →
## 真点【开始探索】看选神界面（无信者第一项、？？？？点不了）→ 真点日神 → 开局看信物进包、奉日神、信仰开关 →
## 测试辅助把信赖补到 10 / 25 / 50 看档位与服务 → 存档退出 → 测试辅助把局外改成「老档」（清迁移标记、万神院没来、仓库放信物、对局记录奉过狩猎之神）→ 重开存档位看迁移
const TAG := "PT845"
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


func _sub(key: String) -> void:
	_click(_ms()._sub_btns[key])


func _faith_line() -> String:
	var r := _flow.run
	if r == null: return "（没有局）"
	var charms := []
	for inst in r.board.items():
		if Pantheon.is_charm((inst as ItemInstance).def): charms.append(String((inst as ItemInstance).def.id))
	var calls := {}
	for id in r.map.node_ids():
		_scan(r.map.get_node(id).content, calls)
	return "信仰开 %s、赐福 %s、经验加成 %.2f、奉 「%s」、有效「%s」、背包里的信物 %s、图上无名祭坛 %s" % [str(r.faith_enabled), str(r.faith_bless), r.faith_xp_bonus, String(r.selected_faith), String(r.active_faith_id()), str(charms), str(calls)]


func _scan(v: Variant, hits: Dictionary) -> void:
	if v is Dictionary:
		for k in v: _scan(v[k], hits)
	elif v is Array:
		for e in v: _scan(e, hits)
	elif (v is String or v is StringName) and String(v).begins_with("faith_call"):
		hits[String(v)] = int(hits.get(String(v), 0)) + 1


func _meta_line() -> String:
	var m := _flow.meta
	var wc := []
	for inst in m.warehouse.items():
		if Pantheon.is_charm((inst as ItemInstance).def): wc.append(String((inst as ItemInstance).def.id))
	return "仓库信物 %s、金币 %d、prologue3_done %s；万神院到了 %s、档 %d、信赖 %d、成功撤离 %d 局、信仰开 %s、奉过 %s、后勤小键 %s" % [str(wc), m.funds, str(m.has_unlock(&"prologue3_done")), str(Pantheon.arrived(m)), Pantheon.tier(m), m.commissions.rep_of(Pantheon.FACTION), m.commissions.formal_extractions, str(_flow.faith_open()), str(m.gods_worshipped), str(_ms()._sub_btns.keys()) if _ms() != null and "_sub_btns" in _ms() else "-"]


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


func _setup_go() -> bool:
	if _flow.screen != GameFlow.Screen.SETUP: return false
	var sp: Node = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("step_difficulty") and n.has_method("depart"): sp = n
	if sp == null: return false
	if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return false
	if not sp.next_page(): sp.depart()
	return false


func _process(_d: float) -> bool:
	_f += 1
	if _f % 250 == 0: print("%s ♥ f %d st %d 屏 %d wait %d" % [TAG, _f, _st, _flow.screen if _flow != null else -1, _wait])
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
			L("新档进营地：%s" % _meta_line())
			_tab("expedition"); _wait = 30; _st = 4
		4:
			if scr == GameFlow.Screen.META:
				_start_click(); _wait = 40; _st = 5
		5:
			if scr == GameFlow.Screen.META:
				L("（第 %d 局）点了【开始探索】还在营地；选神界面 %s" % [_k + 1, str(_ms().god_pick() != null)])
				if _ms().god_pick() != null: _st = 20; return false
				_start_click(); _wait = 40; return false
			if scr == GameFlow.Screen.SETUP:
				_setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("第 %d 局开局（没经过选神）：%s" % [_k + 1, _faith_line()])
			if _k == 0: shot("run1_map")
			var moves: Array = _flow.run.travel.available_moves()
			var pick := int(moves[0])
			for mv in moves:
				var tt := NodeEvents.effective_type(_flow.run.map.get_node(int(mv)))
				if not (tt in [&"battle", &"elite", &"core"]): pick = int(mv); break
			L("　　走到相邻的 %d（%s）" % [pick, String(NodeEvents.effective_type(_flow.run.map.get_node(pick)))])
			_flow.step_to(pick); _wait = 60; _st = 6
		6:
			if (scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP) and not _settle(): _wait = 10; return false
			_flow.run.force_extract(); _flow.resume()
			L("测试辅助：走了一步后直接撤离（force_extract）")
			_wait = 40; _st = 7
		7:
			if scr == GameFlow.Screen.RESULT:
				_k += 1
				L("第 %d 局结算：撤离 %s；成功撤离计数 %d；这一局来营地的 %s" % [_k, str(_flow.result.is_extracted()), _flow.meta.commissions.formal_extractions, str(_flow.last_arrived)])
				if _k == 3: shot("result3")
				_game.base().proceed(); _wait = 60; _st = 8
				return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		8:
			if scr != GameFlow.Screen.META: return false
			var arr: Control = _ms().arrival()
			L("回营地（第 %d 局后）：%s；到来通知 %s" % [_k, _meta_line(), ("「%s」" % _labels_under(arr).replace("\n", " / ")) if arr != null else "没有"])
			if _k < 3:
				_tab("expedition"); _wait = 30; _st = 4; return false
			_wait = 60; _st = 9
		9:
			var arr: Control = _ms().arrival()
			shot("arrival")
			if arr == null: L("（第 3 次后没有到来通知）"); _st = 11; return false
			var ok: Button = null
			for b in arr.find_children("*", "Button", true, false):
				if (b as Button).is_visible_in_tree(): ok = b
			L("到来通知的键：%s" % (ok.text if ok != null else "（没找到）"))
			_click(ok); _wait = 30; _st = 10
		10:
			L("点了【知道了】：通知还在 %s；%s" % [str(_ms().arrival() != null), _meta_line()])
			_tab("logistics"); _wait = 25; _st = 11
		11:
			if not _ms()._sub_btns.has("pantheon"): L("后勤没有万神院小键：%s" % str(_ms()._sub_btns.keys())); _st = 13; return false
			_sub("pantheon"); _wait = 30; _st = 12
		12:
			var p = _ms().pantheon_panel()
			L("万神院页：%s" % (_labels_under(p).replace("\n", " / ").left(600) if p != null else "（没有）"))
			L("　　排版：%s" % _overflow(p))
			shot("pantheon_page")
			_st = 13
		13:
			_tab("expedition"); _wait = 30; _st = 14
		14:
			_start_click(); _wait = 40; _st = 15
		15:
			var gp: Control = _ms().god_pick()
			if gp == null: L("点【开始探索】没出选神界面（屏 %d）" % scr); _st = 99; return false
			var keys := []
			for b in gp.find_children("Choose_*", "Button", true, false):
				keys.append("%s「%s」%s" % [String(b.name).trim_prefix("Choose_"), (b as Button).text, "（灰）" if (b as Button).disabled else ""])
			L("选神界面：%s" % _labels_under(gp).replace("\n", " / ").left(600))
			L("　　键：%s" % str(keys))
			L("　　排版：%s" % _overflow(gp))
			shot("god_pick")
			var hunt := _named("Choose_hunt") as Button
			if hunt != null: _click(hunt)
			_wait = 20; _st = 16
		16:
			L("点灰着的狩猎之神：选神界面还在 %s；选的 %s" % [str(_ms().god_pick() != null), String(Pantheon.choice(_flow.meta))])
			_click(_named("Choose_sun")); _wait = 40; _st = 17
		17:
			if scr == GameFlow.Screen.META: L("点日神后还在营地（选神界面 %s）" % str(_ms().god_pick() != null)); _wait = 30; return false
			if scr == GameFlow.Screen.SETUP: _setup_go(); _wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN: _game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("奉日神开局：%s；局外 %s" % [_faith_line(), _meta_line()])
			_game.base().toggle_bag(); _wait = 25; _st = 18
		18:
			shot("bag_with_charm")
			_game.base().toggle_bag()
			for rep in [10, 25, 50]:
				_assist_done([], Pantheon.FACTION, rep)
				L("测试辅助：信赖补到 %d：档 %d；可选的神 %s；经验加成服务 %s；赐福服务 %s；access %s" % [rep, Pantheon.tier(_flow.meta), str(["brute", "sun", "skill", "hunt", "earth", "nature"].filter(func(x): return Pantheon.god_open(_flow.meta, StringName(x)))), str(Pantheon.has_service(_flow.meta, Pantheon.SERVICE_XP)), str(Pantheon.has_service(_flow.meta, Pantheon.SERVICE_BLESS)), str(Pantheon.access(_flow.meta))])
			L("存档退出：%s" % str(_flow.save_and_quit())); _wait = 40; _st = 19
		19:
			_flow.continue_game(); _wait = 40; _st = 30
		20:
			_st = 15
		30:
			if not _settle(): _wait = 10; return false
			L("读回这一局：%s" % _faith_line())
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 31
		31:
			if scr == GameFlow.Screen.RESULT:
				var back := []
				for inst in _flow.meta.warehouse.items():
					if Pantheon.is_charm((inst as ItemInstance).def): back.append(String((inst as ItemInstance).def.id))
				L("奉日神这一局撤离：仓库里的信物 %s（应该没有：信物不带回）" % str(back))
				_game.base().proceed(); _wait = 60; _st = 32
				return false
			_settle(); _wait = 10
		32:
			if scr != GameFlow.Screen.META: return false
			var back := []
			for inst in _flow.meta.warehouse.items():
				if Pantheon.is_charm((inst as ItemInstance).def): back.append(String((inst as ItemInstance).def.id))
			L("回营地后仓库里的信物 %s；%s" % [str(back), _meta_line()])
			# 老档迁移：把这份局外改成「老档」样子
			var m := _flow.meta
			m.flags.erase(String(Pantheon.MIGRATED)); m.flags.erase(Pantheon.MIGRATED)
			m.commissions.arrived.erase(String(Pantheon.FACTION))
			m.commissions.rep.erase(String(Pantheon.FACTION))
			m.gods_worshipped.clear()
			var ch := Pantheon.charm_of(_flow.items, &"brute")
			var inst := _put(String(ch.id)) if ch != null else null
			m.history.append({"faith_top": {"id": "hunt"}})
			set_meta("funds", m.funds)
			_flow.save_meta()
			L("测试辅助（模拟老档）：清掉迁移标记、万神院没来、信赖清零、奉过的神清空；仓库放一枚 %s；对局记录加一行奉过狩猎之神；金币 %d" % [String(ch.id) if ch != null else "-", m.funds])
			_flow.use_slot(_flow.slot); _wait = 30; _st = 33
		33:
			var m := _flow.meta
			var left := []
			for inst in m.warehouse.items():
				if Pantheon.is_charm((inst as ItemInstance).def): left.append(String((inst as ItemInstance).def.id))
			L("重开存档位（迁移）：万神院到了 %s、档 %d、奉过 %s、可选 %s；仓库信物 %s；金币 %d → %d；迁移标记 %d；迁移记录 %s" % [str(Pantheon.arrived(m)), Pantheon.tier(m), str(m.gods_worshipped), str(["brute", "sun", "skill", "hunt", "earth", "nature"].filter(func(x): return Pantheon.god_open(m, StringName(x)))), str(left), int(get_meta("funds")), m.funds, m.flag(Pantheon.MIGRATED), str(m.migration_log.filter(func(r): return String(r.get("kind", "")) == "pantheon"))])
			_flow.use_slot(_flow.slot); _wait = 20; _st = 34
		34:
			L("再开一次（不重复迁移）：金币 %d；迁移记录条数 %d" % [_flow.meta.funds, _flow.meta.migration_log.filter(func(r): return String(r.get("kind", "")) == "pantheon").size()])
			_st = 99
		_:
			quit(0); return true
	return false
