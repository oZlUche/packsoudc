extends SceneTree
## 游戏测试 v8.56（PR #927）：日神日月盘、回放条日夜色带（沿用 nb923 的走法）。参数 <outdir>
## 第 1 局（新档拒教程、无信者、自由模式第一次进图）：看先弹开局质变、选完才放地图讲解 → 撤离
## 测试辅助：万神院到来、五档 → 第 2 局奉蛮神：开局质变四选一（应只有蛮神的质变牌），选【神罚】→ 升到 30 级，逐批记下摆出的牌（按优先表挑），事后核对出牌条件 →
## 神恩栏、顶端栏小图标 → 走到相邻战斗点，战前屏看【神罚】键、真点
const TAG := "SD927"
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

var _dial_back := false
var _endk := 0
var _dial_hover := false


func _bv() -> Control:
	for n in root.find_children("*", "", true, false):
		if n.has_method("sun_dial") and n.has_method("timeline") and (n as Control).is_visible_in_tree(): return n
	return null


func _tip_node() -> Node:
	var bv := _bv()
	return bv.get("_tip") if bv != null else null


func _tipshow() -> bool:
	var t = _tip_node()
	return t != null and t.has_method("is_showing") and t.is_showing()


func _tiptext() -> String:
	var t = _tip_node()
	return _labels_under(t).replace("\n", " / ").left(240) if t != null else "-"


func _dial_check(tag: String) -> void:
	var bv := _bv()
	if bv == null: L("　　%s：没找到战斗视图" % tag); return
	var dl: SunDial = bv.sun_dial()
	var tl: ReplayTimeline = bv.timeline()
	var segs := tl.sun_segments
	var shown := 0
	for sg in segs:
		if float(sg[0]) < tl.cursor: shown += 1
	var panels = bv.get("_panels")
	var hid = panels[0].hidden_ids if panels != null and not panels.is_empty() else "-"
	L("　　%s：日月盘 %s，位置 %s，大小 %s，now %.1f，状态 %s；悬浮内容 %s" % [tag, "显示" if dl.visible else "藏着", str(dl.global_position.round()), str(dl.size), dl.now, str(dl.state()), str(dl.tip_parts()).replace("\n", " / ").left(260)])
	L("　　　　回放条：游标 %.1f / %.1f 秒；色带 %d 段，已露出 %d 段，前几段 %s；我方效果栏不挂 %s" % [tl.cursor, tl.duration, segs.size(), shown, str(segs.slice(0, 4)), str(hid)])

var _k := 0
var _chose := false
var _seq := []
var _clicked := false
var _coach_steps := 0
var _hp0 := 0
var _hops := 0


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
	var sp: Node = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("step_difficulty") and n.has_method("depart"): sp = n
	if sp == null: return
	var gb = sp.god_book() if sp.has_method("god_book") else null
	if gb != null: sp.close_god_book(); return
	for c in root.find_children("*", "CoachOverlay", true, false):
		(c as CoachOverlay).next(); return
	if _k == 1 and sp.faith_panel() != null and String(_flow.meta.selected_faith if "selected_faith" in _flow.meta else "") != "sun" and not _chose:
		_chose = true
		L("开局屏奉日神：%s" % str(sp.choose_god(&"sun"))); return
	if sp.needs_spawn(): sp.pick_spawn(sp._preview.entry_ids()[0]); return
	if not sp.next_page(): sp.depart()



func _bp() -> LevelPickPanel:
	var b = _game.base()
	return b.get("_level_pick_panel") if b != null else null


func _lv() -> LevelModule:
	return LevelModule.of(_flow.run)


func _cards_line(p: LevelPickPanel) -> String:
	var ids: Array = p.offered()
	return "%d 张 %s" % [ids.size(), str(ids)]


func _bag() -> Node:
	for n in root.find_children("*", "BagWindow", true, false):
		if (n as Control).is_visible_in_tree(): return n
	return null


func _faith_w() -> Control:
	return _game.base().hud().widgets.get(&"faith", null)


var _before := {}
var _vit0 := ""
var _beasts0 := 0
var _last_pick := ""
var _seed_set := false


## 背包 + 地上的东西：id → 件数（地上记 "地上:" 前缀）
func _inv_snapshot() -> Dictionary:
	var out := {}
	for it in _flow.run.board.items():
		var ii := it as ItemInstance
		var k := "%s(%s,r%d)" % [String(ii.def.id), Names.of(ii.def), ii.def.rarity]
		out[k] = int(out.get(k, 0)) + 1
	if _flow.run.storage != null:
		for it in _flow.run.storage.items():
			var ii2 := it as ItemInstance
			var k2 := "地上:%s(%s,r%d)" % [String(ii2.def.id), Names.of(ii2.def), ii2.def.rarity]
			out[k2] = int(out.get(k2, 0)) + 1
	return out


func _beast_count() -> int:
	var ev = _flow.run.events
	var n := 0
	if ev == null or ev.graph == null or ev.enemies == null: return 0
	for id in ev.graph.node_ids():
		var node = ev.graph.get_node(id)
		if node.type != &"battle" or node.is_visited() or not EnemyKit.has_enemy(node.content): continue
		var d = ev.enemies.enemy(StringName(String(node.content.get("enemy", ""))))
		if d != null and d.species == &"beast": n += 1
	return n


var _mh0 = 0.0
var _bf := 0


func _side(br: BattleResult, side: int) -> String:
	var sd: Dictionary = (br.final.get("sides", [{}, {}]) as Array)[side]
	var res: Dictionary = sd.get("resources", {})
	return "资源 %s；buff %s" % [str(res).left(200), str(sd.get("buffs", {})).left(260)]


func _mechs(br: BattleResult) -> Dictionary:
	var out := {}
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.EFFECT_RESOLVED:
			var k := String(e.payload.get("key", ""))
			if k.begins_with("nature"): out[k] = int(out.get(k, 0)) + 1
	return out


func _lost(br: BattleResult, side: int) -> float:
	var n := 0.0
	for raw in br.log:
		var e := raw as BattleEvent
		if e.name == BattleEvent.DAMAGE and e.side == side:
			n += StatMath.to_float(maxi(0, e.get_int(&"amount")))
	return n


## 战前屏：同一个对手，按牌一张一张拿，跑同种子 30 秒模拟，记下双方最后的样子
## 用战斗记录的文字逐行找没换成文字的 log.xxx
func _narr(br: BattleResult, tag: String) -> void:
	var raw := []
	var mech := []
	for ln in BattleNarrator.lines(br, ["我", "敌"]):
		var t := BattleNarrator.plain(ln)
		if t.contains("log."): raw.append(t.left(80))
		if t.contains("枯萎够数") or t.contains("护佑") or t.contains("收割了") or t.contains("求生本能") or t.contains("治疗够数") or t.contains("withered") or t.contains("Ward") or t.contains("reaped") or t.contains("Will to Live") or t.contains("healed enough"):
			mech.append(t.strip_edges().left(60))
	L("NARR %s：原文键 %d 行 %s；机制那几行 %s" % [tag, raw.size(), str(raw), str(mech)])


func _sims() -> void:
	var foe: CombatantSpec = _flow.run.events.pending_battle_spec()
	var lv := _lv()
	var keep: Dictionary = lv.taken.duplicate()
	L("模拟对手：max_hp=%d" % foe.max_hp)
	# 食补、药补、强壮：编进去的上限、负重（测试辅助先放一块兽肉、一瓶药剂）
	for id in ["game_meat", "bandage", "ration", "field_rations"]:
		var ni := ItemInstance.create(_flow.items.get_def(StringName(id)), 0)
		ni.uid = _flow.meta.allocate_uid()
		L("测试辅助：背包放 %s：%s" % [id, str(_flow.run.board.try_add(ni))])
	for cs in [[], ["god_nature_food"], ["god_nature_herb"], ["god_nature_strong"]]:
		lv.taken = {}
		for c in cs: lv.taken[c] = 1
		var me2: CombatantSpec = _flow.run.compile_player()
		var food := NatureCyclePerk.cells_of(_flow.run.board, [&"food", &"ingredient"] as Array[StringName])
		var potion := NatureCyclePerk.cells_of(_flow.run.board, [&"remedy"] as Array[StringName])
		var ctx = _flow.run.buff_context()
		for it in _flow.run.board.items():
			var ii := it as ItemInstance
			if cs.is_empty(): L("　　背包里 %s：%d 格，标签 %s，有战斗数据 %s，算不算 %s" % [Names.of(ii.def), ii.def.cell_count(), str(ii.def.tags), str(ii.def.combat != null), str(EarthSupport.counts(_flow.run.board, ii, &"nature"))])
		L("SIM2 %s：max_hp=%d；耐力上限 %s；负重上限 %s；背包里食物/食材 %d 格、药剂 %d 格" % [str(cs), me2.max_hp, str(me2.baseline.total_of(&"max_stamina") if me2.baseline != null else "-"), str(ctx.carry_capacity_of(int(_flow.run.character.weight_capacity))), food, potion])
	# 求生本能：没武器时会被打到一半以下
	lv.taken = {"god_nature_survive": 1, "god_nature_rejuv": 1}
	var rs := RandomNumberGenerator.new(); rs.seed = 7
	var brs := BattleSim.run(_flow.run.compile_player(), foe, rs, 30.0)
	L("SIM 求生本能（没武器）：机制记号 %s" % str(_mechs(brs)))
	_narr(brs, "求生本能（没武器）")
	# 清掉不参战的杂物，腾地方放武器
	var removed := 0
	for it in _flow.run.board.items():
		var ii := it as ItemInstance
		if ii.def.combat == null and not _flow.run.board.acts_as_bag(ii.def) and not ii.def.is_anchor():
			_flow.run.board.remove(ii.uid); removed += 1
	L("测试辅助：拿走 %d 件不参战的杂物" % removed)
	for id in ["broadsword"]:
		var wi := ItemInstance.create(_flow.items.get_def(StringName(id)), 0)
		wi.uid = _flow.meta.allocate_uid()
		L("测试辅助：背包放武器 %s：%s" % [id, str(_flow.run.board.try_add(wi))])
	var sets := [[], ["god_nature_decay"], ["god_nature_decay", "god_nature_decay_up"], ["god_nature_guard"], ["god_nature_guard", "god_nature_guard_up"], ["god_nature_reap"], ["god_nature_reap", "god_nature_reap_up"], ["god_nature_bounty"], ["god_nature_cycle"], ["god_nature_cycle", "god_nature_cycle_up"], ["god_nature_rejuv"], ["god_nature_poison"], ["god_nature_guard", "god_nature_rejuv"], ["god_nature_guard", "god_nature_guard_up", "god_nature_rejuv"]]
	for cs in sets:
		lv.taken = {}
		for c in cs: lv.taken[c] = 1
		var me: CombatantSpec = _flow.run.compile_player()
		var rng := RandomNumberGenerator.new(); rng.seed = 7
		var br := BattleSim.run(me, foe, rng, 30.0)
		L("SIM %s：我方 max_hp=%d；胜者 %d，时长 %s；敌方失去 %.0f，我方失去 %.0f" % [str(cs), me.max_hp, br.winner, str(br.duration), _lost(br, 1), _lost(br, 0)])
		L("　　我方 %s" % _side(br, 0))
		L("　　敌方 %s" % _side(br, 1))
		L("　　机制记号 %s" % str(_mechs(br)))
		_narr(br, str(cs))
	lv.taken = keep


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
			_start_click(); _wait = 40; _st = 5
		5:
			if scr == GameFlow.Screen.META:
				_start_click(); _wait = 40; return false
			if scr == GameFlow.Screen.SETUP:
				_setup_go(); _wait = 20; return false
			if scr == GameFlow.Screen.EVENT: _settle(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP: return false
			if _flow.run.phase == RunState.Phase.PICK_SPAWN:
				_game.base().pick_spawn(_flow.run.map.entry_ids[0]); _wait = 20; return false
			_wait = 30; _st = 30
		30:
			for c in root.find_children("*", "CoachOverlay", true, false):
				if _coach_steps == 0: shot("k%d_coach" % (_k + 1))
				L("　　选牌前的教练层第 %d 步：%s（选牌窗 %s）" % [_coach_steps + 1, _labels_under(c).left(80), "开着" if _bp() != null else "没开"])
				_coach_steps += 1; (c as CoachOverlay).next(); _wait = 10; return false
			var p := _bp()
			L("　　章节 %s" % String(_flow.run.chapter.id))
			var lv := _lv()
			L("第 %d 局进地图：奉「%s」，%d 级，欠选牌 %d，选牌窗 %s，教练层走了 %d 步" % [_k + 1, String(_flow.run.active_faith_id()), lv.level(), lv.pending(), "开着" if p != null else "没开", _coach_steps])
			if p == null: _st = 33; return false
			L("　　现在这张 %s；窗里的字：%s" % [str(lv.current_pick()), _labels_under(p).left(400)])
			L("　　摆出 %s；换牌 %d、剔牌 %d；排版：%s" % [_cards_line(p), lv.rerolls_left(), lv.removals_left(), _overflow(p.get_parent())])
			shot("k%d_opening" % (_k + 1))
			var first: Array = p.offered()
			var at := 0
			if _k == 1:
				for cid in ["god_nature_decay","god_nature_reap","god_nature_guard","god_nature_bounty","god_nature_cycle","god_nature_grow","god_nature_decay_up"]:
					L("　　牌 %s：eligible=%s" % [cid, str(_lv().eligible(StringName(cid)))])
			_click(p._cards.get_child(at) as Control); _wait = 40; _st = 40
		40:
			var cs: Array = root.find_children("*", "CoachOverlay", true, false)
			if not cs.is_empty():
				if _coach_steps < 100: shot("k%d_coach_after_pick" % (_k + 1)); _coach_steps = 100
				L("　　选完以后的教练层：%s（选牌窗 %s）" % [_labels_under(cs[0]).left(80), "开着" if _bp() != null else "没开"])
				(cs[0] as CoachOverlay).next(); _wait = 10; return false
			L("　　选完以后教练层都走完了")
			_st = 31
		31:
			var lv := _lv()
			L("真点第一张后：欠选牌 %d，质变 %s，拿过 %s，选牌窗 %s" % [lv.pending(), str(lv.quals()), str(lv.taken), "开着" if _bp() != null else "收了"])
			if _k == 0: _st = 35; return false
			if _k == 1: L("（第 2 局不升级，直接走到战斗点）"); _st = 50; return false
			var got := lv.gain(1000000.0, LevelModule.SRC_EVENT)
			L("测试辅助加经验值 %.0f：%d 级，欠选牌 %d" % [got, lv.level(), lv.pending()])
			L("　　体力 %d / %d（下面遇到【耐行】就选它）" % [_flow.run.vitality.current, _flow.run.vitality.maximum])
			_seq = []; _wait = 20; _st = 32
		32:
			for c in root.find_children("*", "CoachOverlay", true, false):
				(c as CoachOverlay).next(); _wait = 10; return false
			var lv := _lv()
			if lv.pending() <= 0:
				L("选完：%s" % " ".join(_seq))
				L("　　质变 %s；拿过 %d 种；【耐行】%d 张，体力 %d / %d" % [str(lv.quals()), lv.taken.size(), lv.count_of(&"card_vitality"), _flow.run.vitality.current, _flow.run.vitality.maximum])
				_st = 33; return false
			var p := _bp()
			if p == null:
				_game.base().show_level_pick(); _wait = 10; return false
			var cur := lv.current_pick()
			var ids: Array = p.offered()
			var n: int = ids.size()
			_seq.append("%d%s×%d" % [int(cur.get("level", 0)), ("Q" + ("通" if bool(cur.get("generic", false)) else "")) if bool(cur.get("qual", false)) else "", n])
			L("BATCH lv=%d qual=%s taken_before=%s offered=%s" % [int(cur.get("level", 0)), str(bool(cur.get("qual", false))), JSON.stringify(lv.taken.keys()), JSON.stringify(ids)])
			if bool(cur.get("qual", false)) and int(cur.get("level", 0)) == 6:
				L("6 级质变位：窗里的字 %s；排版 %s" % [_labels_under(p).left(300), _overflow(p.get_parent())])
				shot("k%d_qual6" % (_k + 1))
			var pick := 0
			var best := 99
			var pri := ["god_nature_tough", "god_nature_herb_sense", "god_nature_food_sense", "god_nature_sow", "god_nature_seed", "god_nature_wane", "god_nature_harvest", "god_nature_near", "god_nature_breed", "god_nature_talk", "god_nature_talk_up", "god_nature_breed_up", "god_nature_near_up", "god_nature_harvest_up", "god_nature_wane_up", "god_nature_rejuv"]
			for i in ids.size():
				var r := pri.find(String(ids[i]))
				if r < 0 and String(ids[i]).begins_with("god_nature"): r = 50
				if r >= 0 and r < best: best = r; pick = i
			L("PICK %s" % String(ids[pick]))
			_before = _inv_snapshot()
			_vit0 = "%d/%d" % [_flow.run.vitality.current, _flow.run.vitality.maximum]
			_beasts0 = _beast_count()
			_last_pick = String(ids[pick])
			p.choose(pick); _wait = 4; _st = 39
		39:
			var after := _inv_snapshot()
			var added := []
			for k in after:
				if int(after[k]) > int(_before.get(k, 0)): added.append("%s×%d" % [k, int(after[k]) - int(_before.get(k, 0))])
			var vit := "%d/%d" % [_flow.run.vitality.current, _flow.run.vitality.maximum]
			var b1 := _beast_count()
			if not added.is_empty() or vit != _vit0 or b1 != _beasts0:
				L("　　拿 %s 后：多了 %s；体力 %s → %s；地图上的野兽战斗点 %d → %d" % [_last_pick, str(added), _vit0, vit, _beasts0, b1])
			_st = 32
		33:
			_hover_at(Vector2(900, 700))
			var fw := _faith_w()
			L("顶端栏信仰徽记：%s；质变小图标 %s，多出来的「%s」" % [("在" if fw != null and fw.visible else "不在"), str(fw.call("favor_ids")) if fw != null else "-", fw.call("favor_more_text") if fw != null else "-"])
			shot("k%d_topbar" % (_k + 1))
			_game.base().toggle_bag(); _wait = 40; _st = 34
		34:
			var bw = _bag()
			if bw == null: L("（背包没开）"); _st = 35; return false
			var fv: FavorPanel = bw.favor
			L("背包（状态界面）：神恩栏 %s；栏里 %s；窗宽 %.0f；排版 %s" % [str(fv.visible), str(fv.slot_ids()), bw.window_size().x, _overflow(bw)])
			if fv.visible:
				for i in fv.slot_ids().size(): L("　　第 %d 格悬浮：%s" % [i + 1, fv.tip_text(i).replace("\n", " / ").left(160)])
			shot("k%d_status" % (_k + 1))
			_game.base().toggle_bag(); _wait = 20; _st = 35
		35:
			if _k == 1: _st = 50; return false
			_flow.run.force_extract(); _flow.resume(); _wait = 40; _st = 36
		36:
			if scr == GameFlow.Screen.RESULT:
				_game.base().proceed(); _wait = 60; _st = 37; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.MAP: _settle(); _wait = 10
		37:
			if scr != GameFlow.Screen.META: return false
			var arr: Control = _ms().arrival()
			if arr != null:
				for b in arr.find_children("*", "Button", true, false):
					if (b as Button).is_visible_in_tree(): _click(b); break
				_wait = 30; return false
			var bk := _flow.meta.commissions
			bk.arrived[String(Pantheon.FACTION)] = 0
			bk.rep[String(Pantheon.FACTION)] = 100
			bk.signed[String(Pantheon.FACTION)] = 1     # 五档要签过约
			_flow.sync_commissions(); _flow.save_meta(); _flow.meta.changed.emit()
			L("测试辅助：万神院到来、声望 %d；开局多一张 %s" % [Pantheon.rep(_flow.meta), str(Pantheon.access(_flow.meta).get("opening_extra", false))])
			_k = 1; _coach_steps = 0; _wait = 20; _st = 3
		50:
			if scr == GameFlow.Screen.EVENT: _settle(); _wait = 10; return false
			if scr != GameFlow.Screen.MAP:
				var top = _game.overlay() if _game.overlay() != null else _game.base()
				if top != null and top.has_method("proceed"): top.proceed()
				elif scr != GameFlow.Screen.PREBATTLE: _flow.resume()
				_wait = 20; return false
			var lv := _lv()
			var moves: Array = _flow.run.travel.available_moves()
			var kinds := moves.map(func(m): return String(NodeEvents.effective_type(_flow.run.map.get_node(int(m)))))
			var near := float(lv.god_state.get(NatureCyclePerk.NEAR_KEY, 0.0))
			L("第 %d 步：相邻 %s；亲近自然攒的 %s；拿着亲近自然 %s" % [_hops, str(kinds), str(near), str(lv.has_card(NatureCyclePerk.NEAR))])
			var pick := -1
			if near <= 0.0 and lv.has_card(NatureCyclePerk.NEAR):
				for mv in moves:
					var nd = _flow.run.map.get_node(int(mv))
					if NodeEvents.effective_type(nd) in [&"event", &"search", &"shop", &"rest"] and not nd.is_visited(): pick = int(mv); break
			if pick < 0:
				for mv in moves:
					if NodeEvents.effective_type(_flow.run.map.get_node(int(mv))) in [&"battle", &"elite"]: pick = int(mv); _st = 51; break
			if pick < 0:
				for mv in moves:
					if NodeEvents.effective_type(_flow.run.map.get_node(int(mv))) != &"extract": pick = int(mv); break
			_hops += 1
			if pick < 0 or _hops > 8: L("走不下去了"); _st = 99; return false
			L("　　走到 %d（%s）" % [pick, String(NodeEvents.effective_type(_flow.run.map.get_node(pick)))])
			_flow.step_to(pick); _wait = 60
			if _st == 51: return false
			_st = 49
		49:
			if scr == GameFlow.Screen.EVENT: _settle(); _wait = 10; return false
			if scr == GameFlow.Screen.MAP:
				L("　　到了，亲近自然攒的 %s；最近的告示 %s" % [str(_lv().god_state.get(NatureCyclePerk.NEAR_KEY, 0.0)), _labels_under(_game.base()).left(0)])
				_st = 50; return false
			if scr == GameFlow.Screen.PREBATTLE:
				L("　　这个点有守卫，进了战前屏；亲近自然攒的 %s" % str(_lv().god_state.get(NatureCyclePerk.NEAR_KEY, 0.0)))
				_st = 51; return false
			var top = _game.overlay() if _game.overlay() != null else _game.base()
			L("　　（屏 %d，往下走）" % scr)
			if top != null and top.has_method("proceed"): top.proceed()
			else: _flow.resume()
			_wait = 30
		51:
			if scr != GameFlow.Screen.PREBATTLE:
				if scr == GameFlow.Screen.EVENT: _settle(); _wait = 10; return false
				L("（没进战前屏，屏 %d）" % scr); _st = 99; return false
			var keys := []
			var talk: Button = null
			for n in root.find_children("*", "Button", true, false):
				var bb := n as Button
				if not bb.is_visible_in_tree(): continue
				keys.append("[%s%s]" % [bb.text, "（灰）" if bb.disabled else ""])
				if bb.has_meta("perk_option") and String(bb.get_meta("perk_option")) == "talk": talk = bb
			var en = _flow.run.events.enemies.enemy(StringName(String((_flow.run.events.pending_battle.get("content", {}) as Dictionary).get("enemy", ""))))
			L("战前屏：对手 %s（%s）；键 %s；动物交谈键 %s" % [String(en.id) if en != null else "-", String(en.species) if en != null else "-", " ".join(keys), "有" if talk != null else "没有"])
			shot("prebattle"); _st = 53
		53:
			var lv := _lv()
			L("真打一场：奉「%s」；拿过 %s" % [String(_flow.run.active_faith_id()), str(lv.taken)])
			_flow.run.compile_player()
			var fb: BaseButton = null
			var texts := []
			for n in root.find_children("*", "Button", true, false):
				var bb := n as Button
				if not bb.is_visible_in_tree(): continue
				texts.append(bb.text)
				var tl := bb.text.to_lower()
				if bb.text.contains("开战") or tl.contains("fight") or tl.contains("battle") or tl.contains("engage"): fb = bb
			var want := UiText.t("pre.fight")
			if fb == null:
				for n in root.find_children("*", "BaseButton", true, false):
					var bb2 := n as BaseButton
					if bb2.is_visible_in_tree() and (String(bb2.tooltip_text) == want or _labels_under(bb2).contains(want)): fb = bb2; break
			if fb == null:
				for n in root.find_children("*", "", true, false):
					if n.has_method("start_battle"): L("（没找到开战键，直接调 start_battle；看得见的键 %s；屏 %d；带悬浮的 %s）" % [str(texts), _flow.screen, str(root.find_children("*", "BaseButton", true, false).filter(func(x): return (x as BaseButton).is_visible_in_tree()).map(func(x): return "%s:%s" % [x.name, (x as BaseButton).tooltip_text.left(20)]))]); n.start_battle(); break
				_bf = 0; _wait = 30; _st = 54; return false
			L("　　真点【%s】" % want)
			_click(fb); _bf = 0; _wait = 30; _st = 54
		54:
			if scr == GameFlow.Screen.BATTLE:
				_bf += 1
				if _bf in [200, 600, 1000]: _dial_check("第 %d 帧" % _bf)
				if _bf in [300, 700, 1200]:
					shot("battle_%d" % _bf)
					L("　　战斗中（第 %d 帧）：%s" % [_bf, _labels_under(_game.base()).replace("\n", " ").left(300) if _game.base() != null else "-"])
				if _bf > 150 and (_bf % 50 == 0 or _endk > 0):
					for n in root.find_children("*", "", true, false):
						var sc = n.get_script()
						if sc != null and String(sc.resource_path).ends_with("battle_screen.gd"):
							var nx = n.get("_next")
							if nx != null and is_instance_valid(nx) and (nx as Control).is_visible_in_tree():
								L("　　战斗打完：%s" % _labels_under(n).replace("\n", " ").left(700))
								if _endk == 0:
									_dial_check("打完"); shot("battle_end")
									_bv().seek(_bv().timeline().duration * 0.3); _endk = 1; _wait = 10; return false
								if _endk == 1:
									_dial_check("往回拖到三成"); shot("scrub_back")
									var dl: SunDial = _bv().sun_dial()
									_hover_at(dl.get_global_rect().get_center()); _endk = 2; _wait = 15; return false
								if _endk == 2:
									L("　　悬停日月盘：悬浮窗 %s：%s" % ["开着" if _tipshow() else "没开", _tiptext()]); shot("dial_hover")
									_hover_at(Vector2(20, 20)); _bv().seek(_bv().timeline().duration * 0.7); _endk = 3; _wait = 10; return false
								if _endk == 3:
									_dial_check("再拖到七成"); _endk = 4
								_click(nx); return false
				if _bf > 12000: L("（战斗太长，停）"); _st = 99
				return false
			if _bf == 0: return false
			L("战斗结束，屏 %d；战斗帧 %d" % [scr, _bf])
			shot("after_battle")
			var r = _flow.last_payload.get("result", null)
			if r is BattleResult:
				var br := r as BattleResult
				L("　　胜者 %d，时长 %s；我方最后 %s；敌方最后 %s" % [br.winner, str(br.duration), _side(br, 0), _side(br, 1)])
				L("　　机制记号：%s" % str(_mechs(br)))
			_st = 55; _wait = 20
		55:
			if scr == GameFlow.Screen.LOOT:
				L("　　战利品屏：放弃战利品"); _flow.discard_loot(); _wait = 30; return false
			if scr == GameFlow.Screen.EVENT or scr == GameFlow.Screen.RESULT:
				var top = _game.overlay() if _game.overlay() != null else _game.base()
				if top != null and top.has_method("proceed"): top.proceed()
				else: _flow.resume()
				_wait = 30; return false
			if scr != GameFlow.Screen.MAP: return false
			var mh = _flow.run.effective_baseline().base_stats.get(&"max_hp", 0.0)
			L("回到地图")
			_st = 99
		57:
			var p := _bp()
			if p == null and _lv().pending() > 0: _game.base().show_level_pick(); _wait = 20; return false
			if p == null: L("　　（选牌窗没开）"); _st = 58; return false
			L("　　选牌窗：%s；摆 %s；换牌键灰 %s、剔牌键灰 %s；排版 %s" % [_labels_under(p).left(300), str(p.offered()), str(p._reroll.disabled), str(p._remove.disabled), _overflow(p.get_parent())])
			shot("seed_choice")
			_before = _inv_snapshot()
			var at := p.offered().find(&"god_nature_seed_pick")
			_click(p._cards.get_child(maxi(0, at)) as Control); _wait = 30; _st = 58
		58:
			var after := _inv_snapshot()
			var added := []
			for k in after:
				if int(after[k]) > int(_before.get(k, 0)): added.append("%s×%d" % [k, int(after[k]) - int(_before.get(k, 0))])
			L("　　真点【采摘】后：多了 %s；seed_last %s；初种还在 %s；能再进池 %s" % [str(added), str(_lv().god_state.get("seed_last", "-")), str(_lv().count_of(&"god_nature_seed")), str(_lv().eligible(&"god_nature_seed"))])
			shot("after_seed_pick")
			_game.base().toggle_bag(); _wait = 40; _st = 56
		56:
			var bw = _bag()
			if bw != null:
				for cc in bw.find_children("*", "CharacterCard", true, false):
					L("状态界面：生命上限一行 value=%s" % str((cc as CharacterCard).row_of(&"max_hp").get("value", "-")))
				shot("status_after_battle")
				_game.base().toggle_bag()
			_st = 99
		99:
			L("完 err=0"); quit(0); return true
	return false
