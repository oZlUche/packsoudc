## 地图沙盒：从一章开一局，挑出生点，一步一步走（架构文档 5.6 / 5.9 / 7 节，M3-6 → M5）。
##
## 演示的就是这一局的骨架：生成 → 显示 → **挑一个出生点**（每条路线的风格、尽头、风险与收益都亮着，
## 悬停哪个出生点哪条路线加粗）→ 点相邻的点走一步 → 打、掉、搜、买、休息 → 存档 / 读档 → 撤离或战败 → 换种子重来。
##
## M5 之后它只是 [RunState] 的一层皮：一局的全部状态（地图、旅程、体力、钱、棋盘、暂存区、节点事件）都在那里，
## 这里只把结果写进日志、开关搜索 / 商店面板、画图。悬停任何战斗点，底下一行是那个敌人的预览（[EnemyKit]）。
## 所有动作都是公开方法（[method pick_spawn]、[method step]、[method save_run]……），鼠标只是调它们；测试直接调。
extends Control

const CHAPTER := "res://data/chapters/chapter_01.tres"
const SIDE_WIDTH := 320
## 沙盒的开局装备：两个包、两把枪、护甲、医疗包。「选初始背包」的界面是 M6 的事
const KIT: Array[StringName] = [&"bag_leather", &"bag_leather", &"rifle", &"pistol", &"armor", &"medkit"]
const SAVE_PATH := "user://sandbox_run.json"

var _font: Font
var _chapter: ChapterDef = null
var _items: ItemDatabase = null
var _enemies: EnemyDatabase = null
var _sets: SetDatabase = null
var _run: RunState = null
var _seed: int = 1
var _view: MapView
var _shop_box: HBoxContainer
var _search_box: HBoxContainer
var _search_label: Label
var _search_btn: Button
var _leave_btn: Button
var _status: Label
var _hud: Label
var _preview: Label
var _enemy_line: Label
var _routes_box: VBoxContainer
var _log: RichTextLabel


func _ready() -> void:
	_font = UiPalette.cjk_font()
	_build()
	_chapter = load(CHAPTER) as ChapterDef
	if _chapter == null:
		_say("读不到 %s —— 先跑一遍 tools/import_content.gd" % CHAPTER)
		return
	_items = ItemDatabase.new()
	_items.load_dir()
	_enemies = EnemyDatabase.new()
	_enemies.load_all()
	_sets = SetDatabase.new()
	_sets.load_dir()
	regenerate(_seed)


#region 公开动作
func run() -> RunState:
	return _run


func graph() -> MapGraph:
	return _run.map if _run != null else null


## 开局之后才有旅程；挑出生点阶段返回 null
func travel() -> MapTravel:
	return _run.travel if _run != null and _run.phase != RunState.Phase.PICK_SPAWN else null


func events() -> NodeEvents:
	return _run.events if _run != null else null


## 按对局种子从这一章开一局，回到「挑出生点」。
func regenerate(seed: int) -> bool:
	_seed = seed
	var state := RunState.start(_chapter, seed, _items, _enemies, _sets, KIT) if _chapter != null else null
	if state == null:
		_run = null
		_view.graph = null
		_say("这一章生成不出图：%s" % (_chapter.map_source.last_error if _chapter != null else ""))
		return false
	state.player_baseline = CombatantBaseline.with_hp(60.0)
	_adopt(state)
	var enemies_placed := 0
	var paid: Array[int] = []
	for id in state.map.node_ids():
		if EnemyKit.has_enemy(state.map.get_node(id).content):
			enemies_placed += 1
		if PaidExtracts.fee_of(state.map.get_node(id)) > 0:
			paid.append(id)
	_say("种子 %d：%d 个点，%d 个敌人%s。挑一个出生点（绿圈的「生」）开始" % [seed, state.map.node_count(), enemies_placed,
		"，付费撤离点 %s（%d 币）" % [str(paid), state.economy.extract_fee] if not paid.is_empty() else ""])
	return true


## 站到某个出生点上开局。返回 false = 那不是出生点。
func pick_spawn(id: int) -> bool:
	if _run == null or not _run.pick_spawn(id):
		return false
	_view.current_id = id
	_view.bold_route = _route_index_of_entry(id)
	_after_move()
	var route := _route_of_entry(id)
	_say("从出生点 %d 出发（%s）。点相邻的点走一步" % [id, String(route.get("style", "?"))])
	return true


## 走到相邻的点。
func step(to_id: int) -> bool:
	return _run != null and _run.step_to(to_id)


func clock_total() -> int:
	return _run.travel.clock.total if travel() != null else 0


## 存这一局。开着的店 / 搜索视为离开
func save_run() -> bool:
	if _run == null:
		return false
	var err := RunSave.write(_run, SAVE_PATH)
	_note("　存档：%s" % ("写到 %s" % SAVE_PATH if err == OK else "失败 %d" % err))
	return err == OK


## 读回上次存的那一局
func load_run() -> bool:
	var state := RunSave.read(_items, _enemies, _sets, SAVE_PATH)
	if state == null:
		_note("　读档：没有存档，或存档读不了")
		return false
	state.player_baseline = CombatantBaseline.with_hp(60.0)
	_seed = state.run_seed
	_adopt(state)
	if state.phase != RunState.Phase.PICK_SPAWN:
		_view.current_id = state.travel.current_id
		_view.bold_route = -1
		_after_move()
	_say("读档：种子 %d，行动点 %d，%s" % [state.run_seed, state.travel.clock.total,
		"挑出生点" if state.phase == RunState.Phase.PICK_SPAWN else ("在点 %d 上" % state.travel.current_id)])
	return true


## 在撤离点上撤离（付费的先付钱）
func extract() -> bool:
	if _run == null:
		return false
	var node := _run.current_node()
	if not _run.try_extract():
		_say("撤不了：不在撤离点上，或付不起（%d 币）" % (_run.events.extract_fee(node) if node != null else 0))
		return false
	_say("撤离成功：行动点 %d，暂存区 %d 件，剩 %d 币。换个种子再来" % [_run.travel.clock.total, _run.storage.item_count(), _run.wallet.balance])
	_refresh_hud()
	return true
#endregion


#region 接线：RunState 与 NodeEvents 的信号写进日志、开关面板
func _adopt(state: RunState) -> void:
	_run = state
	_view.graph = state.map
	_view.current_id = -1
	_view.reachable = {}
	_view.bold_route = -1
	_search_box.visible = false
	_shop_box.visible = false
	state.travel.moved.connect(_on_moved)
	state.travel.refused.connect(func(_i: MoveIntent, why: String): _say("走不了：" + why))
	state.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh_hud())
	state.loot_pending.connect(_on_loot_pending)
	state.phase_changed.connect(func(phase: int, why: StringName):
		if phase == RunState.Phase.DEFEATED:
			_say("战败：%s。换个种子重来" % why)
		_refresh_hud())
	var ev := state.events
	ev.rewarded.connect(func(_n: MapNode, amount: int): _note("　进账 %d 币" % amount))
	ev.shop_opened.connect(_on_shop_opened)
	ev.shop_closed.connect(func(_n: MapNode): _shop_box.visible = false)
	ev.revealed.connect(func(n: MapNode, type: StringName):
		_note("　点 %d 是个「?」：原来是 %s" % [n.id, MapNodeStyle.of(type)["label"]]))
	ev.battle_finished.connect(_on_battle)
	ev.search_opened.connect(_on_search_opened)
	ev.search_closed.connect(func(_n: MapNode, _haul: GridInventory, why: StringName):
		_search_box.visible = false
		_note("　搜索结束（%s）" % why))
	ev.rested.connect(func(_n: MapNode, got: int): _note("　休息：体力 +%d" % got))
	ev.event_resolved.connect(func(_n: MapNode, outcome: StringName, detail: Dictionary):
		_note("　事件：%s %s" % [outcome, str(detail) if not detail.is_empty() else ""]))
	ev.extract_reached.connect(func(_n: MapNode, fee: int):
		_note("　到了撤离点%s：按「撤离」结束这一局" % ("（付费：%d 币，%s）" % [fee, "付得起" if state.wallet.can_afford(fee) else "钱不够"] if fee > 0 else "")))
	_rebuild_routes()
	_refresh_hud()


func _on_battle(n: MapNode, result: BattleResult, won: bool) -> void:
	var who := enemy_preview(n.id).get_slice("　", 0)
	_note("　打 %s：%s，%.1f 秒%s" % [who if who != "" else "敌人", "赢了" if won else ("平局，按输算" if result.is_draw() else "输了"),
		result.duration_sec(), "" if won else "，体力 %d/%d" % [_run.vitality.current, _run.vitality.maximum]])
	_refresh_hud()


## 沙盒没有拾取界面：有东西就全拿进暂存区（真正的搜刮界面是 M6 的事）
func _on_loot_pending(box: GridInventory) -> void:
	var names: Array[String] = []
	for inst in box.items():
		names.append((inst as ItemInstance).def.display_name)
	var n := _run.take_all_loot()
	_note("　拾取 %d 件进暂存区：%s（暂存区共 %d 件）" % [n, "、".join(names), _run.storage.item_count()])
	_refresh_hud()


func _on_search_opened(n: MapNode, session: SearchSession) -> void:
	_search_box.visible = true
	session.searched.connect(func(found: Array[StringName], met: Dictionary):
		var names: Array[String] = []
		for id in found:
			names.append(_items.get_def(id).display_name)
		_note("　搜到：%s%s" % ["、".join(names) if not names.is_empty() else "空手", "　—— 有敌人！" if not met.is_empty() else ""])
		_refresh_search_label(session))
	_refresh_search_label(session)
	_note("　搜索点 %d：搜几次你定，每搜一次更险" % n.id)


## 商店：货架上每格一个按钮（名字 + 价），刷新一个按钮，离开一个按钮。买到的进暂存区（RunState 接的）
func _on_shop_opened(n: MapNode, session: ShopSession) -> void:
	if session == null:
		_note("　商店 %d：这一章没有经济规则，店是空的" % n.id)
		return
	_note("　商店 %d：%d 件在架上，刷新 %d 币" % [n.id, session.available().size(), session.refresh_cost()])
	session.bought.connect(func(def: ItemDef, price: int): _note("　买了 %s，花 %d 币，进暂存区" % [def.display_name, price]))
	session.stock_changed.connect(func(): _rebuild_shop(session))
	_rebuild_shop(session)
	_shop_box.visible = true


func _rebuild_shop(session: ShopSession) -> void:
	for child in _shop_box.get_children():
		child.queue_free()
	_shop_box.add_child(_label("商店：", 13, UiPalette.FG))
	for i in session.available():
		var def := _items.get_def(StringName(String(session.stock[i]["id"])))
		var idx := i
		var b := _button("%s %d 币" % [def.display_name if def != null else "?", int(session.stock[i]["price"])],
			func(): _on_buy(session, idx))
		b.disabled = not session.can_buy(i)
		_shop_box.add_child(b)
	var refresh := _button("刷新 %d 币" % session.refresh_cost(), func(): session.refresh())
	refresh.disabled = not session.can_refresh()
	_shop_box.add_child(refresh)
	_shop_box.add_child(_button("离开", func(): session.leave()))


func _on_buy(session: ShopSession, i: int) -> void:
	if session.buy(i) != null:
		_rebuild_shop(session)


func _refresh_search_label(session: SearchSession) -> void:
	_search_label.text = "还能搜 %d 次，下一次遭遇 %.0f%%" % [session.searches_left(), session.next_encounter_chance() * 100.0]
	_search_btn.disabled = not session.can_search()


func _on_search_pressed() -> void:
	if events() != null and events().current_search != null:
		events().current_search.search()


func _on_leave_pressed() -> void:
	if events() != null and events().current_search != null:
		events().current_search.leave()


func _on_moved(intent: MoveIntent, first_visit: bool) -> void:
	_view.current_id = intent.to_id
	_after_move()
	var n := _run.map.get_node(intent.to_id)
	var what: String = MapNodeStyle.of(n.type)["label"]
	if first_visit:
		_note("→ %d %s（花 %d 点）" % [intent.to_id, what, intent.action_cost])
	else:
		_note("→ %d %s，穿行（花 %d 点，这里用过了）" % [intent.to_id, what, intent.action_cost])


func _after_move() -> void:
	var reach := {}
	if travel() != null:
		for id in _run.travel.available_moves():
			reach[id] = true
	_view.reachable = reach
	_view.refresh()
	_refresh_hud()


func _on_node_pressed(id: int, button: int, _shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT or _run == null:
		return
	if _run.phase == RunState.Phase.PICK_SPAWN:
		if not pick_spawn(id):
			_say("先挑一个出生点（绿圈的「生」）")
	else:
		step(id)


## 单步预览：悬停相邻的点，说这一步花几点、去的是什么。挑出生点阶段悬停出生点加粗它那条路线。
func _on_node_hovered(id: int) -> void:
	if _run == null:
		return
	_enemy_line.text = enemy_preview(id)
	if travel() == null:
		_view.bold_route = _route_index_of_entry(id) if id >= 0 else -1
		_preview.text = ""
		return
	if id < 0 or not _view.reachable.has(id):
		_preview.text = ""
		return
	var intent := MapNavigator.resolve_step(_run.map, _run.travel.current_id, id)
	var n := _run.map.get_node(id)
	if intent == null:
		_preview.text = ""
		return
	_preview.text = "→ %s　花 %d 行动点%s" % [
		MapNodeStyle.of(n.type)["label"], intent.action_cost,
		"（用过了，只是穿行）" if n.is_visited() else ""]


## 这个点里的敌人一行摘要；没有敌人就是空串。全图可见（5.10）—— 看不看得见的接缝在这一处
func enemy_preview(id: int) -> String:
	if _run == null or id < 0 or not _run.map.has_node(id):
		return ""
	var content := _run.map.get_node(id).content
	if not EnemyKit.has_enemy(content):
		return ""
	var line := EnemyKit.summary(content, _enemies, _run.pool, _items)
	if _run.drop_rule != null:
		# 幸运 0、没有 buff：沙盒里就是这一章难度下的裸期望。局外 / 地图 buff 是占位来源，接上了自然算进去
		var ctx := LootContext.new()
		ctx.difficulty = _chapter.difficulty
		ctx.add_source(MetaDropBonus.new())
		ctx.add_source(MapDropBonus.new())
		line += "　预计掉 %.1f 件，珍宝 %.0f%%" % [
			DropResolver.expected_count(content, _run.drop_rule, ctx, _items),
			DropResolver.treasure_chance(_run.drop_rule, ctx) * 100.0]
	if _run.economy != null:
		var depth: float = EnemyPlacer.depths_of(_run.map).get(id, 0.0)
		line += "　打赢 +%d 币" % _run.economy.battle_reward(int(content.get("strength", 0)), depth, _chapter.difficulty)
	return line


func _refresh_hud() -> void:
	if _run == null:
		_hud.text = ""
		return
	if travel() == null:
		_hud.text = "行动点 —　　挑出生点　　暂存区 %d 件" % _run.storage.item_count()
		return
	var t := _run.travel
	var extract_near := MapNavigator.nearest_of_type(_run.map, t.current_id, &"extract")
	var rest := MapNavigator.nearest_of_type(_run.map, t.current_id, &"rest")
	var core := MapNavigator.nearest_of_type(_run.map, t.current_id, &"core")
	var tail := ""
	match _run.phase:
		RunState.Phase.DEFEATED:
			tail = "　　【战败】"
		RunState.Phase.EXTRACTED:
			tail = "　　【已撤离】"
	_hud.text = "行动点 %d　　距最近撤离点 %s 步　　距最近休息区 %s 步　　距核心 %s 步　　体力 %d/%d　　货币 %d　　暂存区 %d 件%s" % [
		t.clock.total,
		str(extract_near["steps"]) if int(extract_near["id"]) >= 0 else "—",
		str(rest["steps"]) if int(rest["id"]) >= 0 else "—",
		str(core["steps"]) if int(core["id"]) >= 0 else "—",
		_run.vitality.current, _run.vitality.maximum,
		_run.wallet.balance, _run.storage.item_count(), tail]


func _route_of_entry(id: int) -> Dictionary:
	for route in _run.map.routes:
		if int(route.get("entry_id", -1)) == id:
			return route
	return {}


func _route_index_of_entry(id: int) -> int:
	for i in _run.map.routes.size():
		if int(_run.map.routes[i].get("entry_id", -1)) == id:
			return i
	return -1


## 右栏：每条路线一张卡 —— 出生点、风格、尽头、风险与收益。这是这一章第一个真正的决策，
## 沙盒里就该长得像个决策。
func _rebuild_routes() -> void:
	for child in _routes_box.get_children():
		child.queue_free()
	if _run == null:
		return
	var g := _run.map
	for i in g.routes.size():
		var route: Dictionary = g.routes[i]
		var entry := int(route.get("entry_id", -1))
		var card := Button.new()
		card.text = "出生点 %d · %s → %s\n风险 %.1f　收益 %.1f" % [
			entry, route.get("style", "?"),
			"核心（打 BOSS）" if String(route.get("ends_at", "core")) == "core" else "撤离点（可以不打）",
			float(route.get("risk_x100", 0)) / 100.0, float(route.get("reward_x100", 0)) / 100.0]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_override("font", _font)
		card.add_theme_font_size_override("font_size", 13)
		card.add_theme_color_override("font_color", MapNodeStyle.route_color(i))
		var idx := i
		card.mouse_entered.connect(func(): if travel() == null: _view.bold_route = idx)
		card.mouse_exited.connect(func(): if travel() == null: _view.bold_route = -1)
		card.pressed.connect(func(): pick_spawn(entry))
		_routes_box.add_child(card)
	# 随机生成的图每个点向内连一两条，「一个点接着两个外层点」是常态，逐条列出来是噪音；只报个数
	var warned := MapLayout.for_graph(g).warnings(g)
	if not warned.is_empty():
		_routes_box.add_child(_label("布局：%d 处径向边画不成全垂直（一点接着两个外层点）" % warned.size(),
			11, UiPalette.DIM))
#endregion


#region 界面
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	row.add_child(mid)
	_hud = _label("", 14, UiPalette.FG)
	var hud_box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = UiPalette.PANEL
	st.set_content_margin_all(8)
	hud_box.add_theme_stylebox_override("panel", st)
	hud_box.add_child(_hud)
	mid.add_child(hud_box)
	_view = MapView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.node_pressed.connect(_on_node_pressed)
	_view.node_hovered.connect(_on_node_hovered)
	mid.add_child(_view)
	_preview = _label("", 13, UiPalette.FG)
	_preview.custom_minimum_size.y = 22
	mid.add_child(_preview)
	_enemy_line = _label("", 13, UiPalette.DIM)
	_enemy_line.custom_minimum_size.y = 22
	mid.add_child(_enemy_line)
	_search_box = HBoxContainer.new()
	_search_box.add_theme_constant_override("separation", 8)
	_search_box.visible = false
	_search_label = _label("", 13, UiPalette.FG)
	_search_box.add_child(_search_label)
	_search_btn = _button("搜一次", _on_search_pressed)
	_search_box.add_child(_search_btn)
	_leave_btn = _button("离开", _on_leave_pressed)
	_search_box.add_child(_leave_btn)
	mid.add_child(_search_box)
	_shop_box = HBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 8)
	_shop_box.visible = false
	mid.add_child(_shop_box)

	var side := PanelContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	var ps := StyleBoxFlat.new()
	ps.bg_color = UiPalette.PANEL
	ps.set_content_margin_all(12)
	side.add_theme_stylebox_override("panel", ps)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	side.add_child(col)
	row.add_child(side)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26      # 右上角是 DevNav 的按钮
	col.add_child(spacer)
	col.add_child(_label("地图沙盒", 18, UiPalette.FG))
	_status = _label("", 12, UiPalette.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_status.custom_minimum_size.x = SIDE_WIDTH - 30
	col.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_child(_button("换个种子（R）", func(): regenerate(randi() % 1000000)))
	buttons.add_child(_button("重开这一局", func(): regenerate(_seed)))
	col.add_child(buttons)
	var buttons2 := HBoxContainer.new()
	buttons2.add_child(_button("存档", save_run))
	buttons2.add_child(_button("读档", load_run))
	buttons2.add_child(_button("撤离", extract))
	col.add_child(buttons2)
	col.add_child(HSeparator.new())
	col.add_child(_label("路线：挑一个出生点", 14, UiPalette.FG))
	_routes_box = VBoxContainer.new()
	_routes_box.add_theme_constant_override("separation", 6)
	col.add_child(_routes_box)
	col.add_child(HSeparator.new())
	col.add_child(_label("日志", 14, UiPalette.FG))
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.add_theme_font_override("normal_font", _font)
	_log.add_theme_font_size_override("normal_font_size", 12)
	col.add_child(_log)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_R:
			regenerate(randi() % 1000000)
		KEY_F:
			_view.fit()
		KEY_1:
			_view.zoom = 1.0
			_view.center()
		_:
			return
	get_viewport().set_input_as_handled()


func _say(text: String) -> void:
	_status.text = text


func _note(text: String) -> void:
	_log.append_text(text + "\n")


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(handler)
	return b
#endregion
