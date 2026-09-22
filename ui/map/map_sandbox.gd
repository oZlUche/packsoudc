## 地图沙盒：从一章开局，挑出生点，一步一步走（架构文档 5.6 / 5.9，M3-6）。
##
## 演示的就是这一章的骨架：生成 → 显示 → **挑一个出生点**（每条路线的风格、尽头、风险与收益都亮着，
## 悬停哪个出生点哪条路线加粗）→ 点相邻的点走一步 → 行动点读数变 → 用过的点变灰但仍可走 → 换种子重来。
##
## 它只接线：地图来自 [ChapterDef] 的 [MapSource]，敌人来自这一章的 [EnemyPool]（[EnemyPlacer] 在生成之后
## 放进节点，5.10：地图一生成敌人就定了），走路是 [MapTravel]，画是 [MapView]。
## 悬停任何战斗点，底下一行是那个敌人的预览 —— 和真打时同一个编译器算出来的数（[EnemyKit]）。
## 所有动作都是公开方法（[method pick_spawn]、[method step]），鼠标只是调它们；测试直接调。
extends Control

const CHAPTER := "res://data/chapters/chapter_01.tres"
const SIDE_WIDTH := 320

var _font: Font
var _chapter: ChapterDef = null
var _graph: MapGraph = null
var _travel: MapTravel = null
var _seed: int = 1
var _items: ItemDatabase = null
var _enemies: EnemyDatabase = null
var _pool: EnemyPool = null
var _drop_rule: DropRule = null
var _node_rules: NodeRules = null
var _economy: EconomyRules = null
var _wallet: Wallet = null
var _events: NodeEvents = null
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
	_pool = _enemies.pool(_chapter.enemy_pool)
	if _chapter.drop_rule != &"":
		_drop_rule = load(ContentPaths.asset_file("drop_rules", String(_chapter.drop_rule))) as DropRule
	if _chapter.node_rules != &"":
		_node_rules = load(ContentPaths.asset_file("node_rules", String(_chapter.node_rules))) as NodeRules
	if _chapter.economy_rules != &"":
		_economy = load(ContentPaths.asset_file("economy_rules", String(_chapter.economy_rules))) as EconomyRules
	regenerate(_seed)


#region 公开动作
func graph() -> MapGraph:
	return _graph


func travel() -> MapTravel:
	return _travel


## 按对局种子从这一章拿一张图，回到「挑出生点」。
func regenerate(seed: int) -> bool:
	_seed = seed
	_travel = null
	_graph = _chapter.map_source.resolve(seed) if _chapter != null else null
	_view.graph = _graph
	_view.current_id = -1
	_view.reachable = {}
	_view.bold_route = -1
	if _graph == null:
		_say("这一章生成不出图：%s" % (_chapter.map_source.last_error if _chapter != null else ""))
		return false
	var placed := _place_enemies()
	var paid := PaidExtracts.mark(_graph, _economy)
	_say("种子 %d：%d 个点，%d 个敌人%s。挑一个出生点（绿圈的「生」）开始" % [seed, _graph.node_count(), placed,
		"，付费撤离点 %s（%d 币）" % [str(paid), _economy.extract_fee] if not paid.is_empty() else ""])
	_rebuild_routes()
	_refresh_hud()
	return true


## 敌人在生成之后、开局之前放好（5.10）。这一章没有敌人池就什么都不放
func _place_enemies() -> int:
	if _pool == null or _items == null or _enemies == null:
		return 0
	var done := EnemyPlacer.fill(_graph, _pool, _enemies, _items, _chapter.difficulty, _scale_id())
	if not (done["skipped"] as Array).is_empty():
		_note("有 %d 个战斗点没挑到敌人：%s" % [(done["skipped"] as Array).size(), str(done["skipped"])])
	if int(done["dropped"]) > 0:
		_note("有 %d 件道具放不进棋盘，跳过了 —— 档位表的棋盘该再大点" % int(done["dropped"]))
	return int(done["placed"])


## 这一章的规模 id（有规模模板的生成器才有）。敌人池按它加档
func _scale_id() -> StringName:
	var cfg: Resource = _chapter.map_source.generator_config if _chapter != null and _chapter.map_source != null else null
	if cfg == null or not cfg.has_method("scale"):
		return &""
	var p = cfg.call("scale")
	return p.id if p != null else &""


## 站到某个出生点上开局。返回 false = 那不是出生点。
func pick_spawn(id: int) -> bool:
	if _graph == null or not _graph.entry_ids.has(id) or _travel != null:
		return false
	_travel = MapTravel.new(_graph, ActionClock.new())
	_travel.vitality = Vitality.new()
	_travel.moved.connect(_on_moved)
	_travel.refused.connect(func(_i: MoveIntent, why: String): _say("走不了：" + why))
	_wire_events()
	_travel.start_at(id)
	_view.current_id = id
	_view.bold_route = _route_index_of_entry(id)
	_after_move()
	var route := _route_of_entry(id)
	_say("从出生点 %d 出发（%s）。点相邻的点走一步" % [id, String(route.get("style", "?"))])
	return true


## 走到相邻的点。
func step(to_id: int) -> bool:
	if _travel == null:
		return false
	return _travel.step_to(to_id)


func clock_total() -> int:
	return _travel.clock.total if _travel != null else 0


func events() -> NodeEvents:
	return _events
#endregion


#region 节点事件（M4-4）
## 节点事件接在这一局的旅程上：踩到点发生什么全是 NodeEvents 的事，这里只把结果写进日志、开关搜索面板
func _wire_events() -> void:
	_events = null
	if _node_rules == null:
		_note("这一章没有节点规则：踩到点只标用过")
		return
	_events = NodeEvents.new(_graph)
	_events.vitality = _travel.vitality
	_events.rules = _node_rules
	_events.pool = _pool
	_events.enemies = _enemies
	_events.items = _items
	_events.drop_rule = _drop_rule
	_wallet = Wallet.new(_economy.starting_balance if _economy != null else 0)
	_wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh_hud())
	_events.wallet = _wallet
	_events.economy = _economy
	_events.rewarded.connect(func(_n: MapNode, amount: int): _note("　进账 %d 币" % amount))
	_events.shop_opened.connect(_on_shop_opened)
	_events.shop_closed.connect(func(_n: MapNode): _shop_box.visible = false)
	_events.difficulty = _chapter.difficulty
	_events.scale_id = _scale_id()
	_events.player_spec = _player_spec
	_events.revealed.connect(func(n: MapNode, type: StringName):
		_note("　点 %d 是个「?」：原来是 %s" % [n.id, MapNodeStyle.of(type)["label"]]))
	_events.battle_finished.connect(_on_battle)
	_events.loot_ready.connect(_on_loot)
	_events.search_opened.connect(_on_search_opened)
	_events.search_closed.connect(_on_search_closed)
	_events.rested.connect(func(n: MapNode, got: int): _note("　休息：体力 +%d" % got))
	_events.event_resolved.connect(func(_n: MapNode, outcome: StringName, detail: Dictionary):
		_note("　事件：%s %s" % [outcome, str(detail) if not detail.is_empty() else ""]))
	_events.extract_reached.connect(func(_n: MapNode, fee: int):
		_note("　到了撤离点%s：撤离动作是 M6 的事" % ("（付费：%d 币，%s）" % [fee, "付得起" if _wallet.can_afford(fee) else "钱不够"] if fee > 0 else "")))
	_events.defeated.connect(func(why: StringName): _say("战败：%s。换个种子重来" % why))
	_events.bind(_travel)


## 沙盒里的玩家：一块固定的棋盘（手枪、步枪、护甲、医疗包），血比默认厚一点。真正的玩家棋盘是 M5 的事
func _player_spec() -> CombatantSpec:
	var board := GridInventory.new(Vector2i(6, 4), 0, false)
	for id in [&"rifle", &"pistol", &"armor", &"medkit"]:
		var d := _items.get_def(id) if _items != null else null
		if d != null:
			board.try_add(ItemInstance.create(d, 0), true)
	return BattleCompiler.compile(board, CombatantBaseline.with_hp(60.0))


func _on_battle(n: MapNode, result: BattleResult, won: bool) -> void:
	var who := enemy_preview(n.id).get_slice("　", 0)
	_note("　打 %s：%s，%.1f 秒%s" % [who if who != "" else "敌人", "赢了" if won else ("平局，按输算" if result.is_draw() else "输了"),
		result.duration_sec(), "" if won else "，体力 %d/%d" % [_travel.vitality.current, _travel.vitality.maximum]])
	_refresh_hud()


func _on_loot(_n: MapNode, corpse: GridInventory) -> void:
	var names: Array[String] = []
	for inst in corpse.items():
		names.append((inst as ItemInstance).def.display_name)
	_note("　掉落 %d 件：%s" % [names.size(), "、".join(names) if not names.is_empty() else "什么都没有"])


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


func _on_search_closed(_n: MapNode, haul: GridInventory, why: StringName) -> void:
	_search_box.visible = false
	_note("　搜索结束（%s），收获 %d 件在容器里" % [why, haul.item_count()])
	_refresh_hud()


## 商店：货架上每格一个按钮（名字 + 价），刷新一个按钮，离开一个按钮。买到的东西没处放（玩家棋盘是 M5 的事），只记日志
func _on_shop_opened(n: MapNode, session: ShopSession) -> void:
	if session == null:
		_note("　商店 %d：这一章没有经济规则，店是空的" % n.id)
		return
	_note("　商店 %d：%d 件在架上，刷新 %d 币" % [n.id, session.available().size(), session.refresh_cost()])
	session.bought.connect(func(def: ItemDef, price: int): _note("　买了 %s，花 %d 币" % [def.display_name, price]))
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
	if _events != null and _events.current_search != null:
		_events.current_search.search()


func _on_leave_pressed() -> void:
	if _events != null and _events.current_search != null:
		_events.current_search.leave()
#endregion


#region 接线
func _on_moved(intent: MoveIntent, first_visit: bool) -> void:
	_view.current_id = intent.to_id
	_after_move()
	var n := _graph.get_node(intent.to_id)
	var what: String = MapNodeStyle.of(n.type)["label"]
	if first_visit:
		_note("→ %d %s（花 %d 点）%s" % [intent.to_id, what, intent.action_cost,
			"　到了撤离点：撤离动作是 M6 的事" if n.type == &"extract" else ""])
	else:
		_note("→ %d %s，穿行（花 %d 点，这里用过了）" % [intent.to_id, what, intent.action_cost])


func _after_move() -> void:
	var reach := {}
	for id in _travel.available_moves():
		reach[id] = true
	_view.reachable = reach
	_view.refresh()
	_refresh_hud()


func _on_node_pressed(id: int, button: int, _shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	if _travel == null:
		if not pick_spawn(id):
			_say("先挑一个出生点（绿圈的「生」）")
	else:
		# 搜着搜着走了：先离开搜索点（随时可以离开）
		if _events != null and _events.current_search != null:
			_events.current_search.leave()
		if _events != null and _events.current_shop != null:
			_events.current_shop.leave()
		step(id)


## 单步预览：悬停相邻的点，说这一步花几点、去的是什么。挑出生点阶段悬停出生点加粗它那条路线。
func _on_node_hovered(id: int) -> void:
	if _graph == null:
		return
	_enemy_line.text = enemy_preview(id)
	if _travel == null:
		_view.bold_route = _route_index_of_entry(id) if id >= 0 else -1
		_preview.text = ""
		return
	if id < 0 or not _view.reachable.has(id):
		_preview.text = ""
		return
	var intent := MapNavigator.resolve_step(_graph, _travel.current_id, id)
	var n := _graph.get_node(id)
	if intent == null:
		_preview.text = ""
		return
	_preview.text = "→ %s　花 %d 行动点%s" % [
		MapNodeStyle.of(n.type)["label"], intent.action_cost,
		"（用过了，只是穿行）" if n.is_visited() else ""]


## 这个点里的敌人一行摘要；没有敌人就是空串。全图可见（5.10）—— 看不看得见的接缝在这一处
func enemy_preview(id: int) -> String:
	if _graph == null or id < 0 or not _graph.has_node(id):
		return ""
	var content := _graph.get_node(id).content
	if not EnemyKit.has_enemy(content):
		return ""
	var line := EnemyKit.summary(content, _enemies, _pool, _items)
	if _drop_rule != null:
		# 幸运 0、没有 buff：沙盒里就是这一章难度下的裸期望。局外 / 地图 buff 是占位来源，接上了自然算进去
		var ctx := LootContext.new()
		ctx.difficulty = _chapter.difficulty
		ctx.add_source(MetaDropBonus.new())
		ctx.add_source(MapDropBonus.new())
		line += "　预计掉 %.1f 件，珍宝 %.0f%%" % [
			DropResolver.expected_count(content, _drop_rule, ctx, _items),
			DropResolver.treasure_chance(_drop_rule, ctx) * 100.0]
	if _economy != null:
		var depth: float = EnemyPlacer.depths_of(_graph).get(id, 0.0)
		line += "　打赢 +%d 币" % _economy.battle_reward(int(content.get("strength", 0)), depth, _chapter.difficulty)
	return line


func _refresh_hud() -> void:
	if _graph == null:
		_hud.text = ""
		return
	if _travel == null:
		_hud.text = "行动点 —　　挑出生点"
		return
	var extract := MapNavigator.nearest_of_type(_graph, _travel.current_id, &"extract")
	var rest := MapNavigator.nearest_of_type(_graph, _travel.current_id, &"rest")
	var core := MapNavigator.nearest_of_type(_graph, _travel.current_id, &"core")
	_hud.text = "行动点 %d　　距最近撤离点 %s 步　　距最近休息区 %s 步　　距核心 %s 步　　体力 %d/%d　　货币 %d" % [
		_travel.clock.total,
		str(extract["steps"]) if int(extract["id"]) >= 0 else "—",
		str(rest["steps"]) if int(rest["id"]) >= 0 else "—",
		str(core["steps"]) if int(core["id"]) >= 0 else "—",
		_travel.vitality.current, _travel.vitality.maximum,
		_wallet.balance if _wallet != null else 0]


func _route_of_entry(id: int) -> Dictionary:
	for route in _graph.routes:
		if int(route.get("entry_id", -1)) == id:
			return route
	return {}


func _route_index_of_entry(id: int) -> int:
	for i in _graph.routes.size():
		if int(_graph.routes[i].get("entry_id", -1)) == id:
			return i
	return -1


## 右栏：每条路线一张卡 —— 出生点、风格、尽头、风险与收益。这是这一章第一个真正的决策，
## 沙盒里就该长得像个决策。
func _rebuild_routes() -> void:
	for child in _routes_box.get_children():
		child.queue_free()
	if _graph == null:
		return
	for i in _graph.routes.size():
		var route: Dictionary = _graph.routes[i]
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
		card.mouse_entered.connect(func(): if _travel == null: _view.bold_route = idx)
		card.mouse_exited.connect(func(): if _travel == null: _view.bold_route = -1)
		card.pressed.connect(func(): pick_spawn(entry))
		_routes_box.add_child(card)
	# 随机生成的图每个点向内连一两条，「一个点接着两个外层点」是常态，逐条列出来是噪音；只报个数
	var warned := MapLayout.for_graph(_graph).warnings(_graph)
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
