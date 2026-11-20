## 游戏测试 v6.68（报告 344：科技升为一级页签）：参数 <outdir> [normal|slice]
##   normal：新档，记第一段教程打完、统一教程走完（委托页签露出），回基地 →
##     1. 基地导览逐步点【知道了】，每步记目标页签和挖洞矩形是不是那颗页签；
##     2. 真鼠标逐个点六个页签，记落到哪页、右半边仓库露不露；
##     3. 科技页：页在屏内、【升级】【追踪】不被「回主菜单」压住；真鼠标点升级、追踪、换机制树；
##     4. 书架：小键四颗、能点四格、第五格空着，真鼠标点四颗小键各开一扇窗；
##     5. 旧入口 show_tab("tech") 从书架落到科技页签。
##   slice：试玩切片，只记页签集合
extends CliTool

var out := "/tmp/claude-0/b668"
var mode := "normal"
var d: GameDirector = null
var f := 0
var step := 0
var lines: Array[String] = []
var ms = null
var tp = null
var order: Array = []
var oi := 0
var subs: Array = []
var si := 0


func run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	if mode == "slice":
		SliceProfile.forced = SliceProfile.SLICE
	GameDirector.fades_allowed = false
	d = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(d)
	current_scene = d


func L(s: String) -> void:
	print("B668 " + s)
	lines.append(s)


func shot(n: String) -> void:
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png("%s/%s_%s.png" % [out, mode, n])


func click(b: Control) -> void:
	var c := root.get_final_transform() * (b.get_global_rect().get_center())
	Input.warp_mouse(c)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)


func _btn_in(n: Node, key: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == UiText.t(key) and (b as Button).is_visible_in_tree():
			return b
	return null


func _r(c: Control) -> String:
	if c == null: return "null"
	var r := c.get_global_rect()
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


func _in_screen(c: Control) -> bool:
	var vr := Rect2(Vector2.ZERO, ms.size)
	return vr.encloses(c.get_global_rect().grow(-0.5))


func _setup() -> void:
	var flow: GameFlow = d.flow
	var m = flow.meta
	TutorialRewards.mark(m, &"prologue", TutorialRewards.COMPLETED)
	for c in flow.tutorial_chapters():
		m.grant_unlock(c.hidden_by_unlock)
	m.funds = 5000
	m.insight = 10
	L("测试手段：第一段记打完、%d 段教程记走完；金币 5000、见识 10；委托可见 %s" % [flow.tutorial_chapters().size(), str(flow.commissions_visible())])


func tick(_dt: float) -> bool:
	f += 1
	if f < 60 or f % 20 != 0:
		return false
	var flow: GameFlow = d.flow
	if mode == "slice":
		match step:
			0: flow.show_meta()
			1:
				ms = d.base()
				L("切片页签：%s" % str(ms._tab_btns.keys()))
				click(ms._tab_btns["tech"])
			2:
				L("切片点科技：落在 %s；科技页 %s" % [ms.tab(), "看得见" if ms.tech_panel() != null and ms.tech_panel().is_visible_in_tree() else "看不见"])
				shot("01_slice_tech")
			_: return _end()
		step += 1
		return false
	match step:
		0:
			_setup()
			flow.show_meta()
			step = 1
		1:
			ms = d.base()
			L("基地页签（从上到下）：%s" % str(ms._tab_btns.keys()))
			for k in ms._tab_btns:
				L("  页签 %s「%s」%s" % [k, (ms._tab_btns[k] as Button).text, _r(ms._tab_btns[k])])
			L("导览该放 %s；步骤目标 %s" % [str(ms.tour_due()), str(ms.tour_steps().map(func(s): return String(s.get("target", ""))))])
			step = 2
		2:
			var t: CoachOverlay = ms.tour()
			if t == null:
				L("导览：没在放（coach_seen 有 base_tour %s）" % str(flow.meta.coach_seen.has("base_tour")))
				step = 3
				return false
			var tgt := String(t.steps[t.index].get("target", "")) if t.index >= 0 and t.index < t.steps.size() else "?"
			var hole: Rect2 = ms.tour_rect(StringName(tgt))
			var btn: Control = ms._tab_btns.get(tgt.trim_prefix("tab_"), null)
			var same := btn != null and hole == btn.get_global_rect()
			L("导览第 %d/%d 步 [%s] 洞 %s %s：%s" % [t.index + 1, t.steps.size(), tgt, str(hole), "= 那颗页签" if same else "（不是页签）", t.line_text()])
			shot("tour_%d_%s" % [t.index + 1, tgt])
			var ok := _btn_in(t, "coach.ok")
			if ok != null: click(ok)
			else:
				L("  没找到【知道了】")
				step = 3
		3:
			order = ms._tab_btns.keys()
			oi = 0
			step = 4
		4:
			if oi >= order.size():
				step = 6
				return false
			click(ms._tab_btns[order[oi]])
			step = 5
		5:
			var k: String = order[oi]
			var page: Control = ms._pages.get(ms.tab() if ms.tab() != "logistics" else ms._sub, null)
			L("点页签 %s → 落在 %s；页签按下 %s；右半边仓库 %s；中列页 %s" % [k, ms.tab(), str((ms._tab_btns[k] as Button).button_pressed),
				"露着" if ms._right.visible else "收起", _r(page)])
			shot("tab_%d_%s" % [oi + 1, k])
			oi += 1
			step = 4
		6:
			click(ms._tab_btns["tech"])
			step = 7
		7:
			tp = ms.tech_panel()
			var menu := ms.get_node_or_null("MainMenuButton") as Control
			var page: Control = ms._pages["tech"]
			L("科技页：页 %s 在屏内 %s；科技面板 %s；回主菜单 %s" % [_r(page), str(_in_screen(page)), _r(tp), _r(menu)])
			tp.select(&"warehouse")
			step = 8
		8:
			var menu := ms.get_node_or_null("MainMenuButton") as Control
			var up: Button = tp.upgrade_button(&"warehouse")
			var tr: Button = tp.track_button()
			for pair in [["升级", up], ["追踪", tr]]:
				var b: Control = pair[1]
				L("  【%s】%s「%s」；在屏内 %s；和回主菜单重叠 %s" % [pair[0], _r(b), (b as Button).text if b != null else "", str(b != null and _in_screen(b)),
					str(b != null and menu != null and b.get_global_rect().intersects(menu.get_global_rect()))])
			shot("tech_01_warehouse")
			L("升级前：仓库扩建 %d 级；金币 %d" % [TechService.level(flow.meta, &"warehouse"), flow.meta.funds])
			if up != null: click(up)
			step = 9
		9:
			L("真鼠标点升级后：仓库扩建 %d 级；金币 %d；一句「%s」" % [TechService.level(flow.meta, &"warehouse"), flow.meta.funds, tp.line_text()])
			var tr: Button = tp.track_button()
			if tr != null: click(tr)
			step = 10
		10:
			L("点追踪后：存档追踪「%s」；结算小纸那行「%s」" % [String(flow.meta.tracked_tech), flow.tech_target_line()])
			shot("tech_02_tracked")
			click(tp.tree_tab(TechDef.TREE_MECHANISM))
			step = 11
		11:
			L("点机制树页签：当前树 %s" % tp.current_tree())
			tp.select(&"pack")
			step = 12
		12:
			var up: Button = tp.upgrade_button(&"pack")
			L("机制树选行囊：【升级】%s；见识 %d" % [_r(up), flow.meta.insight])
			if up != null: click(up)
			step = 13
		13:
			L("真鼠标点升级后：行囊 %d 级；见识 %d" % [TechService.level(flow.meta, &"pack"), flow.meta.insight])
			shot("tech_03_mech")
			click(ms._tab_btns["shelf"])
			step = 14
		14:
			var sb: Dictionary = ms.sub_tab_buttons("shelf")
			subs = sb.keys()
			si = 0
			var cells := []
			var sv = ms.shelf_view()
			for i in ms.SHELF_CELLS.size():
				cells.append("%d:%s/%s" % [i + 1, ms.SHELF_CELLS[i], sv._piece_of(sv._cells[i], false)])
			L("书架：小键 %s；能点的格 %s；六格（键/图）%s" % [str(subs.map(func(k): return "%s「%s」" % [k, (sb[k] as Button).text])), str(ms.shelf_buttons().keys()), str(cells)])
			shot("shelf_01")
			step = 15
		15:
			if si >= subs.size():
				step = 17
				return false
			click(ms.sub_tab_buttons("shelf")[subs[si]])
			step = 16
		16:
			L("点小键 %s → 开着的窗 %s；页 %s" % [subs[si], ms.shelf_open(), ms.tab()])
			shot("shelf_sub_%d_%s" % [si + 1, subs[si]])
			ms.close_shelf()
			si += 1
			step = 15
		17:
			ms.show_tab("tech")
			L("旧入口 show_tab(\"tech\")：落在 %s；书架窗 %s；科技页 %s" % [ms.tab(), "「%s」" % ms.shelf_open(), "看得见" if tp.is_visible_in_tree() else "看不见"])
			step = 18
		18:
			flow.save_meta()
			flow.to_main_menu()
			step = 19
		19:
			flow.continue_game()
			step = 20
		20:
			ms = d.base()
			L("回主菜单再进基地：页签 %s；落在 %s；导览 %s" % [str(ms._tab_btns.keys()), ms.tab(), "又放了" if ms.tour() != null else "不再放"])
			click(ms._tab_btns["tech"])
			step = 21
		21:
			L("再进科技：仓库扩建 %d 级、行囊 %d 级、追踪「%s」" % [TechService.level(flow.meta, &"warehouse"), TechService.level(flow.meta, &"pack"), String(flow.meta.tracked_tech)])
			shot("tech_04_reenter")
			step = 22
		_:
			return _end()
	return false


func _end() -> bool:
	var fl := FileAccess.open("%s/%s_log.txt" % [out, mode], FileAccess.WRITE)
	fl.store_string("\n".join(lines) + "\n")
	fl = null
	finish(0)
	return false
