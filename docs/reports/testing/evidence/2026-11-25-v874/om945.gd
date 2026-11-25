extends SceneTree
## 游戏测试 v8.74（PR #945）：老存档的万神院 → 神殿自选。参数 <outdir> <mode> <rep> <worshipped,逗号分隔>
## make（v8.73）：新档拒教程 → 测试辅助：万神院到了、声望设成 rep、奉过的神 → 存档退出
## check（v8.74）：主菜单【继续】→ 看解锁的神殿、声望、解锁机会、红点 → 后勤万神院页 → 出征屏信仰条
const TAG := "OM945"
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

var _mode := ""
var _P: Variant = Pantheon
var _rep := 0
var _was: Array = []
const GODS := ["brute", "sun", "nature", "skill", "hunt", "earth"]


func _dot(b: Control) -> String:
	if b == null: return "-"
	var d := b.get_node_or_null("RedDot") as RedDot
	return "无" if d == null or not d.visible else str(d.count)


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		var a := OS.get_cmdline_user_args()
		_mode = a[1] if a.size() > 1 else "check"
		_rep = int(a[2]) if a.size() > 2 else 0
		_was = Array(a[3].split(",", false)) if a.size() > 3 else []
		return false
	if _f > 8000: L("超时 st %d" % _st); quit(1); return true
	if _wait > 0: _wait -= 1; return false
	var m := _flow.meta if _flow != null else null
	if _mode == "make":
		if _st < 3:
			if _boot(): _st = 3
			return false
		if _st == 3:
			m.commissions.arrived[String(Pantheon.FACTION)] = 1
			m.commissions.rep[String(Pantheon.FACTION)] = _rep
			for g in _was: m.gods_worshipped.append(StringName(g))
			_flow.save_meta()
			L("老版本：万神院到了 %s、声望 %d、奉过 %s；能奉 %s" % [str(Pantheon.arrived(m)), m.commissions.rep_of(Pantheon.FACTION), str(m.gods_worshipped), str(GODS.filter(func(x): return Pantheon.god_open(m, StringName(x))))])
			_wait = 30; _st = 99; return false
		L("完 err=0"); quit(0); return true
	match _st:
		0:
			if _f < 90: return false
			L("主菜单【继续】：%s" % str(_flow.continue_game())); _wait = 90; _st = 1
		1:
			L("读进来：声望 %d、解锁的神殿 %s、挣到 %d 次、还剩 %d 次、能奉 %s、迁移标记 %d；红点 后勤 %s" % [m.commissions.rep_of(Pantheon.FACTION), str(m.get("temples")), _P.call("chances_earned", m), _P.call("chances", m), str(GODS.filter(func(x): return Pantheon.god_open(m, StringName(x)))), m.flag(&"pantheon_temples_migrated"), _dot(_ms()._tab_btns.get("logistics", null))])
			_tab("logistics"); _wait = 30; _st = 2
		2:
			if _ms()._sub_btns.has("pantheon"): _click(_ms()._sub_btns["pantheon"])
			_wait = 30; _st = 3
		3:
			L("万神院页：%s" % _labels_under(_ms().pantheon_panel()).left(400))
			shot("pantheon")
			_flow.save_meta(); _st = 4; _wait = 10
		4:
			var p := OS.get_user_data_dir() + "/slots/1/meta.json"
			var j = JSON.parse_string(FileAccess.get_file_as_string(p))
			L("存档里：temples %s、flags 里有迁移标记 %s" % [str(j.get("temples", "?")) if j is Dictionary else "?", str((j.get("flags", {}) as Dictionary).has(String(&"pantheon_temples_migrated"))) if j is Dictionary else "?"])
			_st = 99
		99:
			L("完 err=0"); quit(0); return true
	return false
