extends SceneTree
## 游戏测试 v7.49（PR #798，报告 365）：8 个新敌人、warden 改名「看守」、兽名按难度加前缀、头像铜 / 银 / 金。参数 <outdir>
## 一、名牌墙：游戏自己的 Nameplate + enemy_layers，新敌人和几个老敌人各画铜 / 银 / 金三档，截图、记名字和框图；
## 二、真开局：新档拒教程 → 测试辅助解锁难度 → 开局屏真点【+】到 Ⅳ → 进地图 → 走到相邻的普通战 → 战前屏看对手名牌（应是金）
const TAG := "E798"
const IDS := ["molten_lizard", "frost_mane", "thunder_vulture", "miasma_spider", "tusk_boar", "centurion", "condenser_automaton", "arc_coil", "warden", "cave_bear"]
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

var _wall: Control = null
var _sp: Node = null


func _plate_info(p: Nameplate) -> String:
	var ps := p.portrait_slot
	var frame := "-"
	if ps != null and ps.frame != null and ps.frame.texture != null: frame = ps.frame.texture.resource_path.get_file()
	var pic := ps.picture.texture.resource_path.get_file() if ps != null and ps.picture != null and ps.picture.texture != null else "（占位）"
	var rel := ps.relief.texture.resource_path.get_file() if ps != null and ps.relief != null and ps.relief.texture != null else "-"
	return "「%s」底 %s、浮雕 %s、框 %s" % [_labels_under(p), pic, rel, frame]


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
			_wall = PanelContainer.new()
			_wall.set_anchors_preset(Control.PRESET_FULL_RECT)
			var g := GridContainer.new()
			g.columns = 3
			_wall.add_child(g)
			var cl := CanvasLayer.new(); cl.layer = 100
			root.add_child(cl); cl.add_child(_wall)
			for id in IDS:
				var def := _flow.enemies.enemy(StringName(id))
				if def == null: L("%s 不在敌人库" % id); continue
				var row := []
				for m in 3:
					var art := Nameplate.enemy_layers(StringName(id), m)
					var p := Nameplate.new().setup(EnemyRank.prefix(def, m) + Names.of(def), "", art["face"], Nameplate.COMPACT_PORTRAIT, art["frame"], art["overlay"])
					g.add_child(p)
					row.append(p)
				set_meta(id, row)
			_wait = 20; _st = 4
		4:
			for id in IDS:
				if not has_meta(id): continue
				var def := _flow.enemies.enemy(StringName(id))
				var row: Array = get_meta(id)
				L("%s（%s，魔兽 %s）：铜 %s；银 %s；金 %s" % [id, Names.of(def), str(def.is_wild()), _plate_info(row[0]), _plate_info(row[1]), _plate_info(row[2])])
			shot("plate_wall")
			_wall.get_parent().queue_free(); _wall = null
			for d in GameFlow.load_difficulties():
				if (d as DifficultyDef).requires_unlock != &"": _flow.meta.grant_unlock(d.requires_unlock)
			_flow.save_meta()
			_flow.next_run_seed = 11
			_tab("expedition")
			set_meta("go", _f)
			_wait = 40; _st = 5
		5:
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
			var d: DifficultyDef = _sp.difficulty()
			if d == null or d.level < 4:
				_sp.step_difficulty(1); _wait = 8; return false
			L("开局屏难度 %d" % d.level)
			_st = 6
		6:
			if scr == GameFlow.Screen.SETUP:
				if _sp.needs_spawn(): _sp.pick_spawn(_sp._preview.entry_ids()[0]); _wait = 15; return false
				if not _sp.next_page(): _sp.depart()
				_wait = 20; return false
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			var run := _flow.run
			var pick := -1
			var dist := MapNavigator.distance_map(run.map, run.travel.current_id)
			var near := []
			for id in run.map.node_ids():
				var n := run.map.get_node(id)
				if n.type == &"battle" and EnemyKit.has_enemy(n.content): near.append([int(dist.get(id, 99)), id, String(n.content.get("enemy", ""))])
			near.sort()
			L("图上普通战（步数、点、敌人）%s" % str(near.slice(0, 8)))
			for m in run.travel.available_moves():
				if run.map.get_node(int(m)).type == &"battle" and pick < 0: pick = int(m)
			if pick < 0: L("相邻没有普通战"); _st = 99; return false
			L("走到相邻普通战 %d（%s）" % [pick, String(run.map.get_node(pick).content.get("enemy", ""))])
			_flow.step_to(pick); _wait = 60; _st = 7
		7:
			L("屏 %d" % scr)
			var plates := []
			for n in root.find_children("*", "Nameplate", true, false):
				if (n as Control).is_visible_in_tree(): plates.append(_plate_info(n))
			for n in root.find_children("*", "", true, false):
				if n is Nameplate and (n as Control).is_visible_in_tree() and not plates.has(_plate_info(n)): plates.append(_plate_info(n))
			L("战前屏名牌：%s" % "；".join(plates))
			shot("prebattle_a4")
			_st = 99
		_:
			quit(0); return true
	return false
