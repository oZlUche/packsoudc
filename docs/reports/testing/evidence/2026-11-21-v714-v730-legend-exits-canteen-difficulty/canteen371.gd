extends SceneTree
## 游戏测试 v7.28（PR #773，报告 371）：灰灯食堂第一批。参数 <outdir>
## 新档拒教程 → 主仓库放一束薄荷叶（老的占位材料）→ 测试辅助：灰灯四份基础单记办成、声望到受托 → 回主菜单再继续 →
## 真点后勤「食堂」看说明板 → 委托页真点《开伙》【办理】→ 看薄荷叶搬进食材仓库 → 测试辅助往食材仓库放食材 → 真点「食堂」→
## 真拖山薯、野莓、蜂蜜罐、兽肉下锅 → 看纸条 → 出征开局 → 看锅空、饱腹、顶栏读数、负重、每秒回血 → 走到新节点饱腹减 1 →
## 用这一局的玩家数据单算一段回血
var out := ""
var _game: Node
var _flow: GameFlow
var _f := 0
var _st := 0
var _wait := 0
var _shots := 0
var _q: Array = []
var _cur := -1
var _free := Vector2i(-1, -1)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameDirector.fades_allowed = false
	_game = (load("res://ui/game/game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game


func L(s: String) -> void:
	print("C371 " + s)


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


func _cp() -> Node:
	return _ms().canteen_panel()


func _put(id: String) -> ItemInstance:
	var d := _flow.items.get_def(StringName(id))
	var inst := ItemInstance.create(d, 0)
	inst.uid = _flow.meta.allocate_uid()
	_flow.meta.warehouse.try_add(inst)
	return inst


func _ids(g) -> Array:
	return g.items().map(func(i): return String((i as ItemInstance).def.id))


func _note() -> String:
	var p = _cp()
	return "%s；%s" % [p._satiety.text if p._satiety != null else "-", _labels_under(p._lines)]


func _hud_meal() -> String:
	for n in root.find_children("*", "", true, false):
		if n is Control and String(n.name).to_lower().contains("meal") and (n as Control).is_visible_in_tree(): return "%s「%s」" % [n.name, _labels_under(n)]
	return "（顶栏没找到饱腹读数）"


func _process(_d: float) -> bool:
	_f += 1
	if _flow == null:
		_flow = _game.flow
		return false
	if _f > 12000:
		L("超时 st %d 屏 %d；页上 %s" % [_st, _flow.screen, _labels_under(root).left(400)]); shot("timeout"); quit(1); return true
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
			L("新档：食堂列出 %s、开 %s；后勤小键 %s" % [str(_flow.canteen_listed()), str(_flow.canteen_open()), str(_ms()._sub_btns.keys())])
			var mint := _put("mint_bundle")
			L("测试辅助：主仓库放一束薄荷叶（uid %d）" % mint.uid)
			var bk := _flow.meta.commissions
			for id in [&"legion_forge_token", &"society_first_survey", &"greylamp_check_scale"]: _flow.report_commission(id)
			for id in [&"greylamp_unsigned_letter", &"greylamp_check_medkits", &"greylamp_permit"]:
				var d := Commissions.def(id)
				if bk.state_of(id) == CommissionBook.DONE: continue
				if not bk.taken().has(id): Commissions.take(bk, d)
				Commissions._complete(_flow.meta, d, _flow.items)
			while bk.rep_of(&"greylamp") < 25: bk.rep["greylamp"] = bk.rep_of(&"greylamp") + 1
			_flow.sync_commissions(); _flow.save_meta()
			L("测试辅助：灰灯开放单和三份基础单记办成、声望 %d；《开伙》%s；食堂列出 %s、开 %s" % [bk.rep_of(&"greylamp"), bk.state_of(&"greylamp_canteen"), str(_flow.canteen_listed()), str(_flow.canteen_open())])
			_flow.to_main_menu(); _wait = 30; _st = 3
		3:
			_flow.continue_game(); _wait = 40; _st = 4
		4:
			if scr != GameFlow.Screen.META: return false
			_tab("logistics"); _wait = 20; _st = 5
		5:
			L("真点「后勤」：小键 %s" % str(_ms()._sub_btns.keys()))
			if not _ms()._sub_btns.has("canteen"): L("没有「食堂」键"); _st = 99; return false
			_click(_ms()._sub_btns["canteen"]); _wait = 20; _st = 6
		6:
			var lp = _ms().locked_page()
			L("真点「食堂」（没办《开伙》）：说明板 %s：%s" % ["看得见" if lp != null and lp.is_visible_in_tree() else "看不见", _labels_under(lp) if lp != null else "-"])
			L("　　排版：%s" % _overflow(lp))
			shot("canteen_locked")
			_tab("commissions"); _wait = 20; _st = 7
		7:
			_click(_named("Sub_story")); _wait = 20; _st = 8
		8:
			var card := _named("Card_greylamp_canteen")
			var rp := _named("Report_greylamp_canteen")
			L("剧情页《开伙》：%s；【办理】%s" % [_labels_under(card), "有" if rp != null else "没有"])
			shot("canteen_story")
			if rp == null: _st = 99; return false
			_click(rp); _wait = 25; _st = 9
		9:
			var c: Canteen = _flow.meta.canteen
			L("真点【办理】后：食堂开 %s；食材仓库 %s（%s）、锅 %s；主仓库还有薄荷叶 %s；告示 %s" % [str(_flow.canteen_open()), str(c.store.size), str(_ids(c.store)), str(c.pot.size), str(_ids(_flow.meta.warehouse).has("mint_bundle")), str(NoticeLayer.history().slice(0, 2).map(func(x): return x.get("text", "")))])
			for id in ["mountain_yam", "wild_berry", "honey_jar", "game_meat", "wild_berry"]:
				var inst := ItemInstance.create(_flow.items.get_def(StringName(id)), 0); inst.uid = _flow.meta.allocate_uid()
				L("　　测试辅助放进食材仓库 %s：%s" % [id, str(c.stash(inst))])
			var ore := ItemInstance.create(_flow.items.get_def(&"iron_ore"), 0); ore.uid = _flow.meta.allocate_uid()
			L("　　测试辅助往食材仓库塞铁矿石：%s" % str(c.stash(ore)))
			_flow.meta.changed.emit()
			_tab("logistics"); _wait = 20; _st = 10
		10:
			_click(_ms()._sub_btns["canteen"]); _wait = 25; _st = 11
		11:
			var p = _cp()
			L("真点「食堂」：页上 %s" % _labels_under(p))
			L("　　纸条：%s" % _note())
			L("　　排版：%s" % _overflow(p))
			shot("canteen_open")
			_q = []
			for want in ["mountain_yam", "wild_berry", "honey_jar", "game_meat"]:
				for i in _flow.meta.canteen.store.items():
					if String((i as ItemInstance).def.id) == want and not _q.has((i as ItemInstance).uid): _q.append((i as ItemInstance).uid); break
			_st = 12
		12:
			if _q.is_empty(): _wait = 10; _st = 15; return false
			_cur = _q.pop_front()
			var p = _cp()
			var inst0 := _flow.meta.canteen.store.get_item(_cur)
			var pot0: GridInventory = _flow.meta.canteen.pot
			_free = Vector2i(-1, -1)
			for y in pot0.size.y:
				for x in pot0.size.x:
					if _free.x < 0 and inst0 != null and pot0.can_place_item(inst0, Vector2i(x, y), inst0.rotation if "rotation" in inst0 else 0): _free = Vector2i(x, y)
			var r: Rect2 = p.store_view.item_rect(_cur)
			var c: Vector2 = root.get_final_transform() * (p.store_view.global_position + r.position + Vector2(p.store_view.cell_px, p.store_view.cell_px) * 0.5)
			Input.warp_mouse(c)
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = c; e.global_position = c
			Input.parse_input_event(e)
			_wait = 3; _st = 13
		13:
			var p = _cp()
			var free := _free if _free.x >= 0 else Vector2i(0, 0)
			var tgt: Vector2 = root.get_final_transform() * (p.pot_view.global_position + p.pot_view.cell_origin_px(free) + Vector2(p.pot_view.cell_px, p.pot_view.cell_px) * 0.5)
			for k in 4:
				var m := InputEventMouseMotion.new()
				var pos: Vector2 = (root.get_final_transform() * p.store_view.global_position).lerp(tgt, (k + 1) / 4.0)
				Input.warp_mouse(pos)
				m.position = pos; m.global_position = pos; m.relative = Vector2(10, 10)
				Input.parse_input_event(m)
			_wait = 3; _st = 14
		14:
			var pos := root.get_mouse_position()
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT; e.pressed = false; e.position = pos; e.global_position = pos
			Input.parse_input_event(e)
			_wait = 8; _st = 141
		141:
			var c: Canteen = _flow.meta.canteen
			var inst := c.pot.get_item(_cur)
			L("　　真拖 uid %d 到锅的空格 %s：锅里 %s；食材仓库 %s；手上还拖着 %s" % [_cur, str(_free), str(_ids(c.pot)), str(_ids(c.store)), str(_cp().drag.is_dragging()) if _cp().drag != null else "-"])
			if inst == null:
				var it := c.store.get_item(_cur)
				if it != null:
					c.store.remove(_cur)
					L("　　　　（拖没进去，测试辅助直接下锅：%s）" % str(c.pot.try_add(it)))
					_flow.meta.changed.emit()
			_st = 12
		15:
			var p = _cp()
			L("下锅后纸条：%s；当前一锅 %s" % [_note(), str(_flow.meta.canteen.current_meal())])
			L("　　排版：%s" % _overflow(p))
			shot("canteen_pot")
			_hover_at(Vector2(-10, -10))
			for id in ["wild_berry", "honey_jar", "mountain_yam", "mint_bundle"]:
				L("　　食材悬浮窗那一行 %s：%s" % [id, ItemTooltip.canteen_line(_flow.items.get_def(StringName(id)))])
			var tot := 0
			for g in [_flow.meta.canteen.pot, _flow.meta.canteen.store]: tot += g.item_count()
			L("　　食材总数（锅 + 食材仓库）%d（放进去 6 件）" % tot)
			var berry := -1
			for i in _flow.meta.canteen.store.items(): if String((i as ItemInstance).def.id) == "wild_berry": berry = (i as ItemInstance).uid
			var r: Rect2 = p.store_view.item_rect(berry)
			var c: Vector2 = root.get_final_transform() * (p.store_view.global_position + r.get_center())
			Input.warp_mouse(c)
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = c; e.global_position = c
			Input.parse_input_event(e)
			for k in 3:
				var m := InputEventMouseMotion.new()
				m.position = c + Vector2(20 * (k + 1), 0); m.global_position = m.position; m.relative = Vector2(20, 0)
				Input.warp_mouse(m.position); Input.parse_input_event(m)
			_wait = 5; _st = 151
		151:
			L("　　拿起剩下那颗野莓不放：手上拖着 %s" % str(_cp().drag.is_dragging()))
			_tab("expedition"); _wait = 20; _st = 152
		152:
			var tot := 0
			for g in [_flow.meta.canteen.pot, _flow.meta.canteen.store]: tot += g.item_count()
			L("　　拖着野莓就点「出征」：食材总数 %d；食材仓库 %s；主仓库里有野莓 %s；手上还拖着 %s" % [tot, str(_ids(_flow.meta.canteen.store)), str(_ids(_flow.meta.warehouse).has("wild_berry")), str(_cp().drag.is_dragging()) if _cp() != null and _cp().drag != null else "-"])
			_tab("expedition"); _wait = 20; _st = 16
		16:
			_flow.next_run_seed = 31
			var sb: Button = _ms().get("_new_run_btn")
			L("出征页：开新局键 %s；页上 %s" % ["有" if sb != null and sb.is_visible_in_tree() else "没有", _labels_under(_ms()).left(300)])
			if sb != null: _click(sb)
			_wait = 40; _st = 17
		17:
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
			_wait = 20; _st = 18
		18:
			var run := _flow.run
			var mod := MealModule.of(run)
			var spec := run.compile_player()
			L("进地图：锅里还剩 %d 件；饱腹 %s；负重加成 %d；每秒回血 固定 %.2f + 生命上限 %.2f%%；顶栏 %s" % [_flow.meta.canteen.pot.item_count(), str(mod.satiety) if mod != null else "（没吃）", run.buff_context().carry_capacity_bonus, spec.meal_regen_hp, spec.meal_regen_hp_pct, _hud_meal()])
			shot("run_meal_hud")
			var rt := CombatantRuntime.from_spec(spec, 0)
			L("　　用这一局的玩家数据算：生命上限 %.0f；每秒回 %.2f（= %.2f + %.0f × %.2f%%）" % [StatMath.to_float(rt.stat(BattleStats.MAX_HP)), StatMath.to_float(rt.meal_hp_rate()), spec.meal_regen_hp, StatMath.to_float(rt.stat(BattleStats.MAX_HP)), spec.meal_regen_hp_pct])
			var moves: Array = run.travel.available_moves()
			var pick := -1
			for m in moves:
				var t := String(NodeEvents.effective_type(run.map.get_node(int(m))))
				if t in ["event", "search", "rest", "shop", "unknown"] and pick < 0: pick = int(m)
			if pick < 0 and not moves.is_empty(): pick = int(moves[0])
			L("测试辅助：走到相邻的新节点 %d（%s）" % [pick, String(NodeEvents.effective_type(run.map.get_node(pick)))])
			_flow.step_to(pick); _wait = 30; _st = 19
		19:
			var mod := MealModule.of(_flow.run)
			L("到新节点：屏 %d；饱腹 %s；顶栏 %s" % [_flow.screen, str(mod.satiety) if mod != null else "-", _hud_meal()])
			shot("run_after_step")
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