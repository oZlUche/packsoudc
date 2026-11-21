extends SceneTree
## 游戏测试：营地里声望跨到「受托」那一刻，后勤有没有当场长出「食堂」小键；《开伙》【完成】跳不跳食堂页。参数 <outdir>
## 新档 → 测试辅助：灰灯前三份办成、声望补到 20、《灰灯会牌》记成「办成了等点完成」→ 回主菜单再继续（页面按 20 声望建好）→
## 真点《灰灯会牌》【完成】（+5 → 25，受托）→ 看后勤小键 → 真点《开伙》【完成】→ 看跳到哪一页
const TAG := "FB2"
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



func _story_click(nm: String) -> void:
	var b := _named(nm)
	if b == null: L("（%s 不在）" % nm); return
	var p := b.get_parent()
	while p != null and not (p is ScrollContainer): p = p.get_parent()
	if p != null: (p as ScrollContainer).ensure_control_visible(b)
	set_meta("target", nm)


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 8000:
		L("超时 st %d" % _st); shot("timeout"); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var bk: CommissionBook = _flow.meta.commissions if _flow.meta != null else null
	if _st < 3:
		if _boot(): _st = 3
		return false
	match _st:
		3:
			_assist_done(["greylamp_check_scale", "greylamp_unsigned_letter", "greylamp_check_medkits"], &"greylamp", 20)
			var d := Commissions.def(&"greylamp_permit")
			if not bk.taken().has(d.id): Commissions.take(bk, d)
			var r := {}
			for k in maxi(1, d.stages[0].count): r = Commissions.credit(_flow.meta, d, 0, "fb2:%d" % k, _flow.items)
			_flow.sync_commissions(); _flow.save_meta()
			L("测试辅助：灰灯声望 %d；《灰灯会牌》%s；食堂列出 %s" % [bk.rep_of(&"greylamp"), bk.state_of(d.id), str(_flow.canteen_listed())])
			_flow.to_main_menu(); _wait = 30; _st = 4
		4:
			_flow.continue_game(); _wait = 40; _st = 5
		5:
			if _flow.screen != GameFlow.Screen.META: return false
			L("继续后：后勤小键 %s" % str(_ms()._sub_btns.keys()))
			_tab("commissions"); _wait = 20; _st = 6
		6:
			_click(_named("Sub_story")); _wait = 20; _st = 7
		7:
			_story_click("Finish_greylamp_permit"); _wait = 15; _st = 8
		8:
			_click(_named(String(get_meta("target")))); _wait = 25; _st = 9
		9:
			L("真点《灰灯会牌》【完成】：状态 %s；声望 %d；食堂列出 %s；后勤小键 %s；页 %s" % [bk.state_of(&"greylamp_permit"), bk.rep_of(&"greylamp"), str(_flow.canteen_listed()), str(_ms()._sub_btns.keys()), _ms().page()])
			_tab("logistics"); _wait = 20; _st = 10
		10:
			shot("logistics_after_permit")
			_tab("commissions"); _wait = 20; _st = 11
		11:
			_click(_named("Sub_story")); _wait = 20; _st = 12
		12:
			L("《开伙》卡：%s" % _labels_under(_named("Card_greylamp_canteen")).left(160))
			_story_click("Finish_greylamp_canteen"); _wait = 15; _st = 13
		13:
			_click(_named(String(get_meta("target")))); _wait = 25; _st = 14
		14:
			L("真点《开伙》【完成】：状态 %s；食堂开 %s；页 %s（应是食堂）；后勤小键 %s" % [bk.state_of(&"greylamp_canteen"), str(_flow.canteen_open()), _ms().page(), str(_ms()._sub_btns.keys())])
			shot("after_canteen")
			_st = 99
		_:
			quit(0); return true
	return false
