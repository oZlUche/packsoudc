extends SceneTree
## 游戏测试 v7.14（PR #766）：局内地图左下图例像卷轴一样卷起 / 放下。参数 <outdir>
## 新档拒教程 → 真点出征、开新局进地图 → 看图例默认放下 → 真点图例 → 动画中途量高度 → 卷起后看高宽、设置、悬停 →
## 回主菜单再继续进地图看还卷着 → 再真点放下
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _lg: Control
var _open_h := 0.0
var _open_w := 0.0
var mode := "first"
var _cl := -1
var _pd := -1


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
	print("L714 " + s)


func shot(n: String) -> void:
	_shots += 1
	var img := root.get_texture().get_image()
	if img != null and out != "": img.save_png("%s/board_%02d_%s.png" % [out, _shots, n])


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


func _all_named(pat: String) -> Array:
	var o := []
	for n in root.find_children(pat, "Control", true, false):
		if (n as Control).is_visible_in_tree(): o.append(n)
	return o


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


func _es() -> Node:
	for n in root.find_children("*", "", true, false):
		if n.has_method("is_options_page") and (n as CanvasItem).is_visible_in_tree(): return n
	return null


func _opts() -> String:
	var es := _es()
	if es == null: return "（没有事件屏）"
	var o := []
	for b in es.get("_option_btns"):
		if is_instance_valid(b): o.append("[%s]%s%s" % [(b as Button).text.replace("\n", " "), "灰" if (b as Button).disabled else "", ("「%s」" % (b as Button).tooltip_text) if (b as Button).tooltip_text != "" else ""])
	return " ".join(o)


func _click_opt(i: int) -> void:
	var es := _es()
	if es == null: return
	var bs: Array = es.get("_option_btns")
	if i < bs.size() and is_instance_valid(bs[i]): _click(bs[i])


func _legend() -> Control:
	for n in root.find_children("*", "", true, false):
		if n is Control and n.has_method("rolled_up") and (n as Control).is_visible_in_tree(): return n
	return null


func _lstate() -> String:
	var lg := _legend()
	if lg == null: return "（找不到图例）"
	var clip := lg.find_child("Scroll", true, false) as Control
	var t := lg.find_child("Title", true, false) as Label
	return "放下 %s、卷着 %s；框 %s；「%s」；卷轴露出高 %.0f；行 %s；设置 legend_open %s；悬停字「%s」" % [str(lg.expanded()), str(lg.rolled_up()), str(lg.get_global_rect()), t.text if t != null else "-", clip.custom_minimum_size.y if clip != null else -1.0, str(lg.row_names()), str(_flow.settings.legend_open), lg.tooltip_text.replace("\n", " / ").left(200)]


func _settings_file() -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	return str(d.get("legend_open", "（没写）")) if d is Dictionary else "?"


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 9000:
		L("超时 st %d 屏 %d" % [_st, _flow.screen]); quit(1); return true
	if _wait > 0:
		_wait -= 1
		return false
	var scr := _flow.screen
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
			if scr != GameFlow.Screen.META: return false
			_flow.next_run_seed = 31
			_tab("expedition"); _wait = 20; _st = 20
		20:
			var sb: Button = _ms().get("_new_run_btn")
			L("出征页：开新局键 %s；页上 %s" % ["有" if sb != null and sb.is_visible_in_tree() else "没有", _labels_under(_ms()).left(200)])
			if mode != "again": shot("expedition_page")
			if sb != null: _click(sb)
			_wait = 40; _st = 3
		3, 13:
			if scr == GameFlow.Screen.SETUP:
				var sp: Node = null
				for n in root.find_children("*", "", true, false):
					if n.has_method("carry_in") and n.has_method("depart"): sp = n
				var eb = sp.get("_enter_btn") if sp != null else null
				if sp != null and sp.needs_spawn():
					sp.pick_spawn(sp._preview.entry_ids()[0]); _wait = 20; return false
				if eb != null and (eb as Button).is_visible_in_tree(): _click(eb)
				elif sp != null: sp.depart()
				_wait = 30; return false
			if scr == GameFlow.Screen.EVENT and bool(_flow.last_payload.get("briefing", false)):
				_flow.close_briefing(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 5; return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_ms().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			_wait = 30; _st = 4 if _st == 3 else 14
		4:
			_lg = _legend()
			if mode == "again":
				L("第二次启动（设置文件没清）开新局进地图：%s；设置文件 legend_open %s" % [_lstate(), _settings_file()])
				shot("legend_second_launch")
				_mouse_at((_lg.find_child("Title", true, false) as Control).get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
				_wait = 30; _st = 15; return false
			L("进地图：图例 %s；设置文件 legend_open %s" % [_lstate(), _settings_file()])
			L("　　排版：%s" % _overflow(_lg))
			_open_h = _lg.size.y; _open_w = _lg.size.x
			shot("legend_open")
			var t := _lg.find_child("Title", true, false) as Control
			GameDirector.fades_allowed = true     # 量 0.2 秒的卷起动画：这一步打开动效
			_mouse_at(t.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
			_wait = 5; _st = 5
		5:
			L("真点「图例」后约 5 帧（动画中途）：%s" % _lstate())
			shot("legend_mid")
			_wait = 30; _st = 6
			GameDirector.fades_allowed = false
		6:
			L("卷起后：%s；高 %.0f → %.0f、宽 %.0f → %.0f；设置文件 legend_open %s" % [_lstate(), _open_h, _lg.size.y, _open_w, _lg.size.x, _settings_file()])
			L("　　排版：%s" % _overflow(_lg))
			_hover_at(_lg.get_global_rect().get_center())
			_wait = 90; _st = 7
		7:
			var tips := []
			for n in root.find_children("*", "", true, false):
				if n is Control and (n as Control).is_visible_in_tree() and String(n.get_class()) in ["PopupPanel", "TooltipPanel"]: tips.append(n.name)
			L("停在卷起的图例上 1.5 秒：悬停字「%s」" % _lg.tooltip_text.replace("\n", " / ").left(300))
			shot("legend_rolled_hover")
			_hover_at(Vector2(900, 300))
			_wait = 10; _st = 30
		30:
			var run := _flow.run
			var cd := CountdownModule.of(run)
			_cl = cd.closing_extract_id() if cd != null else -1
			for n in run.map.nodes.values():
				var mn := n as MapNode
				if NodeEvents.effective_type(mn) == &"extract" and PaidExtracts.fee_of(mn) > 0 and _pd < 0: _pd = mn.id
			L("=== 撤离点：会关的免费点 %d（关在剩 %d）；付费点 %d（费 %d）；倒计时 剩 %d / 共 %d；钱 %d" % [_cl, PaidExtracts.closes_at(run.map.get_node(_cl)) if _cl >= 0 else -1, _pd, PaidExtracts.fee_of(run.map.get_node(_pd)) if _pd >= 0 else -1, cd.left(), cd.limit(), run.events.wallet.balance])
			run.events.pending = {}
			run.travel.current_id = _cl
			run.events.handle(run.map.get_node(_cl)); _flow._flush()
			L("测试辅助：直接站到会关的撤离点上、触发它的事件")
			_wait = 20; _st = 31
		31:
			L("撤离事件（没关）：屏 %d；选项 %s" % [_flow.screen, _opts()])
			shot("exit_open")
			_click_opt(1); _wait = 20; _st = 32
		32:
			var lens: BaseButton = _ms().get("_reopen_btn")
			L("真点「再看看」回地图：屏 %d；放大镜亮 %s「%s」" % [_flow.screen, str(not lens.disabled), lens.tooltip_text])
			_click(lens); _wait = 20; _st = 33
		33:
			L("真点放大镜：屏 %d；选项 %s" % [_flow.screen, _opts()])
			_click_opt(1); _wait = 20; _st = 34
		34:
			var run := _flow.run
			var cd := CountdownModule.of(run)
			@warning_ignore("integer_division")
			run.travel.clock.total = cd.limit() - cd.limit() / 2
			_flow._flush()
			L("测试辅助：倒计时拨到过半：剩 %d；这个点关了 %s" % [cd.left(), str(cd.extract_closed(run.map.get_node(_cl)))])
			_wait = 20; _st = 35
		35:
			var lens: BaseButton = _ms().get("_reopen_btn")
			L("关了以后地图上：放大镜亮 %s「%s」" % [str(not lens.disabled), lens.tooltip_text])
			_ms().reopen()
			L("　　按 N / 放大镜（键灰着，直接调 reopen）：告示 %s" % str(NoticeLayer.history().slice(0, 1).map(func(x): return x.get("text", ""))))
			shot("exit_closed_map")
			var run := _flow.run
			run.events.handle(run.map.get_node(_cl)); _flow._flush()
			L("测试辅助：当作走开又回来，再触发这个点的事件")
			_wait = 20; _st = 36
		36:
			L("撤离事件（关了）：屏 %d；选项 %s" % [_flow.screen, _opts()])
			shot("exit_closed_event")
			_click_opt(0); _wait = 20; _st = 37
		37:
			L("真点灰着的「撤离」：屏 %d；这局结束 %s；告示 %s" % [_flow.screen, str(_flow.run.is_over()), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			if _flow.screen == GameFlow.Screen.EVENT: _click_opt(1)
			_wait = 20; _st = 38
		38:
			var run := _flow.run
			if _pd < 0: L("没有付费撤离点"); _st = 99; return false
			run.events.wallet.balance = 0
			run.events.pending = {}
			run.travel.current_id = _pd
			run.events.handle(run.map.get_node(_pd)); _flow._flush()
			L("测试辅助：钱清零，站到付费撤离点 %d（费 %d）上" % [_pd, PaidExtracts.fee_of(run.map.get_node(_pd))])
			_wait = 20; _st = 39
		39:
			L("付费撤离事件（没钱）：屏 %d；选项 %s" % [_flow.screen, _opts()])
			shot("paid_exit_broke")
			_click_opt(0); _wait = 25; _st = 40
		40:
			var lens: BaseButton = _ms().get("_reopen_btn")
			L("真点「撤离」（没钱）：屏 %d；告示 / 日志 %s；放大镜亮 %s" % [_flow.screen, str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", ""))), str(lens != null and not lens.disabled)])
			if _flow.screen != GameFlow.Screen.MAP:
				var es := _es()
				L("　　结果页：%s" % _labels_under(es).left(200))
				shot("paid_exit_broke_result")
				if es != null: es.proceed()
			_wait = 20; _st = 41
		41:
			var lens: BaseButton = _ms().get("_reopen_btn")
			if _flow.screen != GameFlow.Screen.MAP: L("还不在地图：屏 %d；%s" % [_flow.screen, _labels_under(root).left(300)]); _st = 99; return false
			_flow.run.events.wallet.earn(PaidExtracts.fee_of(_flow.run.map.get_node(_pd)))
			L("回地图：放大镜亮 %s；测试辅助给钱到 %d；真点放大镜" % [str(not lens.disabled), _flow.run.events.wallet.balance])
			_click(lens); _wait = 20; _st = 42
		42:
			L("再打开：屏 %d；选项 %s" % [_flow.screen, _opts()])
			_click_opt(0); _wait = 30; _st = 43
		43:
			L("真点「撤离」（有钱）：屏 %d；这局结束 %s；钱 %d" % [_flow.screen, str(_flow.run.is_over() if _flow.run != null else true), _flow.run.events.wallet.balance if _flow.run != null else -1])
			_st = 99
		14:
			_lg = _legend()
			L("回主菜单再继续进地图：%s" % _lstate())
			shot("legend_after_reload")
			var t := _lg.find_child("Title", true, false) as Control
			_mouse_at(t.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
			_wait = 30; _st = 15
		15:
			L("再真点「图例」：%s；高 %.0f；设置文件 legend_open %s" % [_lstate(), _lg.size.y, _settings_file()])
			L("　　排版：%s" % _overflow(_lg))
			shot("legend_reopen")
			_st = 99
		_:
			quit(0); return true
	return false


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
			bad.append("「%s」出 %s 框（字 %s，框 %s）" % [t, p.name, str(r), str((p as Control).get_global_rect())])
		elif l is Label and (l as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (l as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and c.get_minimum_size().x > c.size.x + 1:
			bad.append("「%s」比自己的框宽（%d > %d）" % [t, int(c.get_minimum_size().x), int(c.size.x)])
	return "查 %d 处，溢出 %d：%s" % [n_checked, bad.size(), "；".join(bad.slice(0, 8))]