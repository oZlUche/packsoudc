extends SceneTree
## 游戏测试 v7.45（PR #799，报告 360 第三批）：进阶十一 —— 只看得见 2 步内的敌情；intel_seen 跟存档；旧档（没有 intel_seen）照常读。参数 <outdir>
## 新档拒教程 → 测试辅助解锁 A1–A11 → 出征开局屏真点难度【+】到 Ⅺ → 出发 → 悬停近处 / 远处敌人点看浮窗 → 走一步 →
## 回主菜单再继续（intel_seen 读回来）→ 测试辅助把局存档里的 intel_seen 删掉（模拟旧档）→ 继续 → 再看近处 / 远处 → 再走一步
const TAG := "A11"
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


func _enemy_pts() -> Array:
	var run := _flow.run
	var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
	var near := -1
	var far := -1
	for id in run.map.node_ids():
		var n := run.map.get_node(id)
		if not EnemyKit.has_enemy(n.content) or not dist.has(id) or n.is_visited(): continue
		if int(dist[id]) <= 2 and int(dist[id]) > 0 and near < 0: near = id
		if int(dist[id]) > 2 and (far < 0 or int(dist[id]) > int(dist[far])): far = id
	return [near, far, dist]


func _tip_of(id: int) -> String:
	var ms = _map()
	if ms.has_method("_on_node_hovered"): ms._on_node_hovered(id)
	var t: String = NodeTooltip.text_for(_flow.run, _flow.run.chapter, _flow.run.map.get_node(id))
	return "浮窗「%s」；画棋盘 %s；预览「%s」" % [t.left(160).replace("\n", " "), str(NodeTooltip.shows_board(_flow.run.map.get_node(id), _flow.run)), ms.enemy_preview(id) if ms.has_method("enemy_preview") else "-"]


func _look(tag: String) -> void:
	var p := _enemy_pts()
	var run := _flow.run
	var dist: Dictionary = p[2]
	var vis := 0
	var total := 0
	for id in run.map.node_ids():
		if EnemyKit.has_enemy(run.map.get_node(id).content):
			total += 1
			if run.intel_visible(id): vis += 1
	L("%s：站在 %d；有敌人的点 %d 个、看得清 %d；intel_seen %d 个" % [tag, run.travel.current_id, total, vis, run.intel_seen.size()])
	for id in [p[0], p[1]]:
		if id < 0: continue
		L("　　点 %d（%d 步，%s）看得清 %s：%s" % [id, int(dist[id]), String(run.map.get_node(id).type), str(run.intel_visible(id)), _tip_of(id)])
		shot("%s_%d" % [tag, id])


func _step_safe() -> bool:
	var run := _flow.run
	for m in run.travel.available_moves():
		var t := String(NodeEvents.effective_type(run.map.get_node(int(m))))
		if t in ["junction", "empty", "rest", "search", "event", "shop", "unknown"] and not EnemyKit.has_enemy(run.map.get_node(int(m)).content):
			L("走到相邻的 %d（%s）" % [int(m), t])
			_flow.step_to(int(m))
			return true
	L("相邻没有不打架的点：%s" % str(run.travel.available_moves()))
	return false


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
		if _flow.has_method("resume"): _flow.resume()
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
			for d in GameFlow.load_difficulties():
				if (d as DifficultyDef).requires_unlock != &"": _flow.meta.grant_unlock(d.requires_unlock)
			_flow.save_meta()
			L("测试辅助：解锁全部难度；能选 %s" % str(_flow.available_difficulties().map(func(d): return d.level)))
			_flow.next_run_seed = 7
			_tab("expedition")
			set_meta("go", _f)
			_wait = 40; _st = 4
		4:
			if _f % 300 == 0: L("（等开局屏：屏 %d，st %d，页 %s）" % [scr, _st, _ms().page() if scr == GameFlow.Screen.META else "-"])
			if scr == GameFlow.Screen.META:
				var sb: Button = _ms().get("_new_run_btn")
				if _f - int(get_meta("go", 0)) > 200 and sb != null: sb.pressed.emit(); _wait = 30; return false
				if sb != null and sb.is_visible_in_tree(): _click(sb)
				_wait = 30; return false
			if scr != GameFlow.Screen.SETUP: return false
			for n in root.find_children("*", "", true, false):
				if n.has_method("step_difficulty") and n.has_method("depart"): _sp = n
			if _sp.page() < 2: _sp.next_page(); _wait = 15; return false
			_st = 5
		5:
			var d: DifficultyDef = _sp.difficulty()
			if d == null or d.level < 11:
				var pb: Button = _sp._diff_block.plus_btn
				if pb.disabled: L("【+】灰了，停在 %s" % str(d.level if d != null else 0)); _st = 6; return false
				var lv0 := d.level if d != null else 0
				if has_meta("lv") and int(get_meta("lv")) == lv0:
					if not has_meta("warned"): L("真点【+】没加上去（停在 %d，键在 %s，%s）：改调 step_difficulty" % [lv0, str(pb.get_global_rect()), "看得见" if pb.is_visible_in_tree() else "看不见"]); set_meta("warned", true)
					_sp.step_difficulty(1)
				else: _click(pb)
				set_meta("lv", lv0)
				_wait = 12; return false
			L("真点【+】到 Ⅺ：%s；挑战 %s" % [d.display_name if "display_name" in d else String(d.id), str(_sp.challenge_lines().back())])
			L("　　说明：%s" % (Names.pick(d.descriptions, d.description) if "descriptions" in d else d.description))
			shot("setup_a11")
			_st = 6
		6:
			if scr == GameFlow.Screen.SETUP:
				if _sp.needs_spawn(): _sp.pick_spawn(_sp._preview.entry_ids()[0]); _wait = 15; return false
				if not _sp.next_page(): _sp.depart()
				_wait = 20; return false
			if not _settle(): _wait = 10; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_map().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			L("进地图：难度 %s；可视距离 %d；侦察距离 %.1f" % [String(_flow.run.difficulty_id), _flow.run.difficulty.intel_range, _flow.run.hooks.run_context().scout_range])
			_look("开局"); _wait = 10; _st = 7
		7:
			_step_safe(); _wait = 40; _st = 8
		8:
			if not _settle(): _wait = 10; return false
			_look("走一步"); set_meta("seen", _flow.run.intel_seen.size())
			L("存档退出：%s" % str(_flow.save_and_quit())); _wait = 30; _st = 9
		9:
			L("回主菜单：局存档 %s" % _flow.save_path)
			_flow.continue_game(); _wait = 40; _st = 10
		10:
			if not _settle(): _wait = 10; return false
			L("再继续：intel_seen %d 个（存前 %d）" % [_flow.run.intel_seen.size(), int(get_meta("seen"))])
			_look("读回来")
			L("存档退出：%s" % str(_flow.save_and_quit())); _wait = 30; _st = 11
		11:
			var path := ProjectSettings.globalize_path(_flow.save_path)
			var txt := FileAccess.get_file_as_string(_flow.save_path)
			var d = JSON.parse_string(txt)
			if not (d is Dictionary): L("局存档读不成 JSON（%s，%d 字）" % [path, txt.length()]); _st = 99; return false
			var had: bool = (d as Dictionary).has("intel_seen")
			var target: Dictionary = d
			if not had and d.has("run") and d["run"] is Dictionary: target = d["run"]; had = target.has("intel_seen")
			target.erase("intel_seen")
			var fa := FileAccess.open(_flow.save_path, FileAccess.WRITE)
			fa.store_string(JSON.stringify(d)); fa.close()
			L("测试辅助（模拟旧档）：局存档原来有 intel_seen %s，删掉写回" % str(had))
			_flow.continue_game(); _wait = 40; _st = 12
		12:
			if not _settle(): _wait = 10; return false
			L("读旧档：屏 %d；intel_seen %d 个" % [_flow.screen, _flow.run.intel_seen.size()])
			_look("旧档")
			_step_safe(); _wait = 40; _st = 13
		13:
			if not _settle(): _wait = 10; return false
			_look("旧档走一步")
			_st = 99
		_:
			quit(0); return true
	return false
