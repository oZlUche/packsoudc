## 地图屏（M6）：一局的主屏。挑出生点 → 点相邻的点走一步 → 事件由 [GameFlow] 排成叠层一屏一屏来 → 撤离。
##
## 它是当年地图沙盒（M3-6 → M5，066 删了）的正式版：同一个 [MapView]，同一份 HUD，日志在右栏；沙盒的换种子 / 重开 / 读档在这里没有，
## 那些是开局屏与主菜单的事。「背包」把整理面板叠在地图上，随时开；撤离按钮只在撤离点上亮。
## 所有动作都是公开方法，鼠标只是调它们；测试直接调。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")
const SIDE_WIDTH := 340

var _run: RunState = null
var _view: MapView
var _hud: Label
var _preview: Label
var _enemy_line: Label
var _status: Label
var _routes_box: VBoxContainer
var _log: RichTextLabel
var _extract_btn: Button
var _bag: Control = null
var _confirm: Control = null
var _step_confirm: Control = null
var _pending_step: int = -1


func open(_payload: Dictionary) -> void:
	_run = flow.run
	_build()
	_adopt()


func refresh() -> void:
	_after_move()


#region 公开动作
func pick_spawn(id: int) -> bool:
	if not flow.pick_spawn(id):
		return false
	_view.current_id = id
	_view.bold_route = _route_index_of_entry(id)
	_after_move()
	_rebuild_routes()
	var route := _route_of_entry(id)
	_say("从出生点 %d 出发（%s）。点相邻的点走一步；B 开背包" % [id, String(route.get("style", "?"))])
	return true


## 走一步。要离开的是个发生过事的点、暂存区里还有值得提的东西（按设置档位），先问一句；否则直接走
func step(to_id: int) -> bool:
	if _run.will_clear_storage() and _run.travel.available_moves().has(to_id) \
			and StorageWarning.should_warn(_run.storage.items(), flow.settings):
		_open_step_confirm(to_id)
		return true
	return flow.step_to(to_id)


## 提示看过了，照走（暂存区里的留在这里）
func confirm_step() -> bool:
	var to := _pending_step
	cancel_step()
	return to >= 0 and flow.step_to(to)


func cancel_step() -> void:
	_pending_step = -1
	if _step_confirm != null:
		_step_confirm.queue_free()
		_step_confirm = null


func step_confirm_open() -> bool:
	return _step_confirm != null


func _open_step_confirm(to_id: int) -> void:
	cancel_step()
	_pending_step = to_id
	var at_risk := StorageWarning.at_risk(_run.storage.items(), flow.settings)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_step_confirm = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := _panel(20)
	panel.custom_minimum_size.x = 520
	center.add_child(panel)
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label("暂存区里还有东西", 20, UiPalette.FG))
	col.add_child(_wrapped("走了它们就留在这个点上了：%s。暂存区是在这个点上腾挪用的，不跟着走（3.4）。想带走先放进棋盘。" % StorageWarning.describe(_run.storage.items()),
		14, UiPalette.STAMINA, 480))
	var list := _log_box(13)
	list.custom_minimum_size.y = 22 * mini(6, at_risk.size() + 1)
	for item in at_risk:
		list.append_text(_item_line(item.def) + "\n")
	col.add_child(list)
	var buttons := _hbox(8)
	buttons.add_child(_button("照走，不要了", func(): confirm_step(), 14))
	buttons.add_child(_button("先整理背包（B）", func():
		cancel_step()
		toggle_bag(), 14))
	buttons.add_child(_button("取消", cancel_step, 14))
	col.add_child(buttons)


## 在撤离点上按「撤离」：先确认 —— 付多少钱、暂存区里有什么带不出去（3.4）。返回 false = 不在撤离点上
func extract() -> bool:
	var node := _run.current_node()
	if node == null or _run.phase != RunState.Phase.ON_MAP or NodeEvents.effective_type(node) != &"extract":
		_say("撤不了：不在撤离点上")
		return false
	_open_confirm(node)
	return true


## 确认撤离。付不起返回 false，留在地图上
func confirm_extract() -> bool:
	cancel_extract()
	var node := _run.current_node()
	if not flow.extract():
		_say("撤不了：付不起（%d 币）" % (_run.events.extract_fee(node) if node != null else 0))
		return false
	return true


func cancel_extract() -> void:
	if _confirm != null:
		_confirm.queue_free()
		_confirm = null


func confirm_open() -> bool:
	return _confirm != null


func _open_confirm(node: MapNode) -> void:
	cancel_extract()
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_confirm = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := _panel(20)
	panel.custom_minimum_size.x = 520
	center.add_child(panel)
	var col := _vbox(10)
	panel.add_child(col)
	col.add_child(_label("撤离？", 20, UiPalette.FG))
	var fee := _run.events.extract_fee(node)
	var affordable := fee <= 0 or _run.wallet.can_afford(fee)
	if fee > 0:
		col.add_child(_wrapped("这是付费撤离点：%d 币（现有 %d 币%s）" % [fee, _run.wallet.balance, "" if affordable else "，付不起"],
			14, UiPalette.FG if affordable else UiPalette.HP, 480))
	var carried := 0
	var carried_value := 0
	for inst in _run.board.items():
		carried += 1
		carried_value += ItemValue.of((inst as ItemInstance).def)
	col.add_child(_wrapped("棋盘上 %d 件、值 %d 币会背出去进仓库；剩 %d 币带出" % [carried, carried_value, _run.wallet.balance - maxi(0, fee)], 14, UiPalette.FG, 480))
	var left := _run.storage.item_count()
	if left > 0:
		var left_value := 0
		var rare := 0
		for inst in _run.storage.items():
			var def := (inst as ItemInstance).def
			left_value += ItemValue.of(def)
			if def.rarity >= 2:
				rare += 1
		col.add_child(_wrapped("暂存区里还有 %d 件（值 %d 币%s）不会带出去 —— 暂存区不参战也不出关（3.4）。想带走先放进棋盘（B）" % [
			left, left_value, "，其中 %d 件稀有以上" % rare if rare > 0 else ""], 14, UiPalette.STAMINA, 480))
	var buttons := _hbox(8)
	var go := _button("确定撤离", func(): confirm_extract(), 14)
	go.disabled = not affordable
	buttons.add_child(go)
	buttons.add_child(_button("再想想", cancel_extract, 14))
	col.add_child(buttons)


## 背包整理面板叠在地图上，再按一次收起
func toggle_bag() -> void:
	if _bag != null:
		_bag.queue_free()
		_bag = null
		return
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_bag = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := _panel(16)
	center.add_child(panel)
	var col := _vbox(10)
	panel.add_child(col)
	var head := _hbox(12)
	head.add_child(_label("背包", 18, UiPalette.FG))
	head.add_child(_button("收起（B）", toggle_bag, 12))
	col.add_child(head)
	var inv := InventoryPanelScript.new()
	inv.setup(_run, font)
	col.add_child(inv)


func bag_open() -> bool:
	return _bag != null
#endregion


#region 接线：RunState 与 NodeEvents 的信号写进日志
func _adopt() -> void:
	_view.graph = _run.map
	_view.current_id = _run.travel.current_id if _run.phase != RunState.Phase.PICK_SPAWN else -1
	_view.reachable = {}
	_view.bold_route = -1
	_run.travel.moved.connect(_on_moved)
	_run.travel.waited.connect(func(actions: int):
		_note("　原地耗了 %d 个行动点" % actions)
		_after_move())
	_run.travel.refused.connect(func(_i: MoveIntent, why: String): _say("走不了：" + why))
	_run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh_hud())
	_run.vitality.changed.connect(func(_c: int, _m: int, _d: int, _r: StringName): _refresh_hud())
	_run.storage.changed.connect(_refresh_hud)
	_run.buffs_changed.connect(_refresh_hud)
	_run.storage_dropped.connect(func(node_id: int, items: Array):
		_note("　离开点 %d：暂存区里的 %s留在了那里" % [node_id, StorageWarning.describe(items)]))
	# 猎手（071）：进了感知范围提示一句；动了就重画标记；被赶回上一个点
	_run.hunter_sensed.connect(func(h: Hunter):
		var def: HunterDef = _run.hunters.def_of(h) if _run.hunters != null else null
		var seen := _run.hunters != null and _run.hunters.visible_hunters().has(h)
		_note("[color=#d9534f]　附近有动静……%s[/color]" % ("（" + def.display_name + "）" if def != null and seen else "")))
	_run.hunters_changed.connect(_refresh_hunter_marks)
	_run.player_expelled.connect(func(to: int):
		_note("[color=#d9534f]　被赶回了点 %d[/color]" % to)
		_view.current_id = to
		_after_move())
	# 侵蚀（075）：预警、推进、结算了、终局 —— 都写进日志，地图上垫色
	_run.erosion_warned.connect(func(band: int, left: int):
		_note("[color=#f0ad4e]　侵蚀预警：第 %d 档还有 %d 步就被侵蚀[/color]" % [band, left])
		_refresh_erosion_view())
	_run.erosion_advanced.connect(func(bands: int):
		_note("[color=#d9534f]　侵蚀推进：最外 %d 档已被侵蚀[/color]" % (bands + 1))
		_refresh_erosion_view()
		_refresh_hud())
	_run.erosion_applied.connect(func(node: MapNode, detail: Dictionary):
		var bits: Array[String] = []
		if int(detail.get("vitality", 0)) > 0:
			bits.append("体力 -%d" % int(detail["vitality"]))
		if int(detail.get("money", 0)) > 0:
			bits.append("钱 -%d" % int(detail["money"]))
		for name in detail.get("items", []):
			bits.append("「%s」烂掉了" % name)
		for line in detail.get("log", []):
			bits.append(String(line))
		_note("[color=#d9534f]　侵蚀区（点 %d，深 %d 层）：%s[/color]" % [node.id, int(detail.get("depth", 0)), "，".join(bits)]))
	_run.erosion_total.connect(func(): _note("[color=#d9534f]　全图都被侵蚀了：快撤[/color]"))
	_refresh_erosion_view()
	if _run.hunters != null and _run.hunters.metric != null and _run.hunters.metric.mode == MapMetric.ABSOLUTE:
		# 绝对距离：把布局坐标按环距归一后交给度量（core 不认识布局）
		var scaled := {}
		var px := _view.positions()
		for id in px:
			scaled[id] = Vector2(px[id]) / RingLayoutBase.RING_STEP
		_run.hunters.metric.set_positions(scaled)
	_refresh_hunter_marks()
	var ev := _run.events
	ev.rewarded.connect(func(_n: MapNode, amount: int): _note("　进账 %d 币" % amount))
	ev.revealed.connect(func(n: MapNode, type: StringName):
		_note("　点 %d 是个「?」：原来是 %s" % [n.id, MapNodeStyle.of(type)["label"]]))
	ev.type_changed.connect(func(n: MapNode, type: StringName):
		_note("　点 %d 变成了%s点" % [n.id, MapNodeStyle.of(type)["label"]])
		_view.refresh())
	ev.battle_finished.connect(func(n: MapNode, result: BattleResult, won: bool):
		var who := enemy_preview(n.id).get_slice("　", 0)
		_note("　打 %s：%s，%.1f 秒" % [who if who != "" else "敌人", "赢了" if won else ("平局，按输算" if result.is_draw() else "输了"), result.duration_sec()]))
	ev.search_closed.connect(func(_n: MapNode, _haul: GridInventory, why: StringName): _note("　搜索结束（%s）" % why))
	ev.rested.connect(func(_n: MapNode, got: int): _note("　休息：体力 +%d" % got))
	ev.extract_reached.connect(func(_n: MapNode, fee: int):
		_note("　到了撤离点%s：按「撤离」结束这一局" % ("（付费：%d 币，%s）" % [fee, "付得起" if _run.wallet.can_afford(fee) else "钱不够"] if fee > 0 else "")))
	_run.phase_changed.connect(func(_p: int, _why: StringName): _refresh_hud())
	_rebuild_routes()
	_after_move()
	if _run.phase == RunState.Phase.PICK_SPAWN:
		_say("%s　种子 %d：%d 个点。挑一个出生点（绿圈的「生」）开始" % [
			_run.chapter.display_name, _run.run_seed, _run.map.node_count()])
	else:
		_say("%s　种子 %d：在点 %d 上，行动点 %d" % [_run.chapter.display_name, _run.run_seed, _run.travel.current_id, _run.travel.clock.total])


func _on_moved(intent: MoveIntent, first_visit: bool) -> void:
	_view.current_id = intent.to_id
	var n := _run.map.get_node(intent.to_id)
	var what: String = MapNodeStyle.of(n.type)["label"]
	if intent.kind == MoveIntent.TELEPORT:
		_note("[color=#b38cff]⇢ %d %s，传送（花 %d 点）%s[/color]" % [intent.to_id, what, intent.action_cost, "" if first_visit else "，这里用过了"])
	else:
		_note(("→ %d %s（花 %d 点）" if first_visit else "→ %d %s，穿行（花 %d 点，这里用过了）") % [intent.to_id, what, intent.action_cost])
	_after_move()


## 侵蚀在地图上：被侵蚀的档垫色、快被侵蚀的那一档闪红环
func _refresh_erosion_view() -> void:
	if _run == null or _view == null:
		return
	var f := _run.travel.erosion as ErosionField if _run.travel != null else null
	if f == null:
		_view.erosion = {}
		return
	var warn := f.next_band() if f.actions_left() >= 0 and f.actions_left() <= f.mechanic.warn_lead_actions else -1
	_view.erosion = {"eroded": f.eroded_bands, "warn": warn}


## HUD 里的侵蚀一句：没有 / 还没开始 / 侵蚀了几档、下一档几步
func _erosion_line() -> String:
	var f := _run.travel.erosion as ErosionField if _run != null and _run.travel != null else null
	if f == null:
		return ""
	if f.is_total():
		return "　　侵蚀：全图"
	if not f.started():
		return "　　侵蚀：%d 步后开始" % f.actions_left()
	return "　　侵蚀 %d 档（下一档 %d 步）" % [f.eroded_bands + 1, f.actions_left()]


## 地图上画谁：看得见的猎手（一直可见的、进了 near_range 的、进了侦察距离的）
func _refresh_hunter_marks() -> void:
	if _run == null or _view == null:
		return
	var marks: Array = []
	if _run.hunters != null:
		for h in _run.hunters.visible_hunters():
			var def: HunterDef = _run.hunters.def_of(h)
			marks.append({"node": h.node_id, "label": def.display_name if def != null else "?"})
	_view.hunters = marks


func _after_move() -> void:
	if _run == null or _view == null:
		return
	var reach := {}
	if _run.phase == RunState.Phase.ON_MAP:
		for id in _run.travel.available_moves():
			reach[id] = true
	_view.reachable = reach
	_view.refresh()
	_refresh_hud()
	_refresh_hunter_marks()
	var node := _run.current_node()
	_extract_btn.disabled = node == null or _run.phase != RunState.Phase.ON_MAP or NodeEvents.effective_type(node) != &"extract"


func _on_node_pressed(id: int, button: int, _shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT or _bag != null or _confirm != null or _step_confirm != null:
		return
	if _run.phase == RunState.Phase.PICK_SPAWN:
		if not pick_spawn(id):
			_say("先挑一个出生点（绿圈的「生」）")
	else:
		step(id)


func _on_node_hovered(id: int) -> void:
	_enemy_line.text = enemy_preview(id)
	if _run.phase == RunState.Phase.PICK_SPAWN:
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
	_preview.text = "→ %s　花 %d 行动点%s" % [MapNodeStyle.of(n.type)["label"], intent.action_cost, "（用过了，只是穿行）" if n.is_visited() else ""]


## 这个点里的敌人一行摘要（5.10：全图可见）；没有敌人就是空串
func enemy_preview(id: int) -> String:
	if _run == null or id < 0 or not _run.map.has_node(id):
		return ""
	var content := _run.map.get_node(id).content
	if not EnemyKit.has_enemy(content):
		return ""
	var line := EnemyKit.summary(content, flow.enemies, _run.pool, flow.items)
	if _run.drop_rule != null:
		var ctx := LootContext.new()
		ctx.difficulty = _run.chapter.difficulty
		ctx.add_source(MetaDropBonus.new())
		ctx.add_source(MapDropBonus.new())
		line += "　预计掉 %.1f 件，珍宝 %.0f%%" % [
			DropResolver.expected_count(content, _run.drop_rule, ctx, flow.items),
			DropResolver.treasure_chance(_run.drop_rule, ctx) * 100.0]
	if _run.economy != null:
		var depth: float = EnemyPlacer.depths_of(_run.map).get(id, 0.0)
		line += "　打赢 +%d 币" % _run.economy.battle_reward(int(content.get("strength", 0)), depth, _run.chapter.difficulty)
	return line


func _refresh_hud() -> void:
	if _run == null or _hud == null:
		return
	if _run.phase == RunState.Phase.PICK_SPAWN:
		_hud.text = "行动点 —　　挑出生点　　体力 %d/%d　　货币 %d　　暂存区 %d 件" % [
			_run.vitality.current, _run.vitality.maximum, _run.wallet.balance, _run.storage.item_count()]
		return
	var t := _run.travel
	var extract_near := MapNavigator.nearest_of_type(_run.map, t.current_id, &"extract")
	var rest := MapNavigator.nearest_of_type(_run.map, t.current_id, &"rest")
	var core := MapNavigator.nearest_of_type(_run.map, t.current_id, &"core")
	_hud.text = "行动点 %d　　距最近撤离点 %s 步　　距最近休息区 %s 步　　距核心 %s 步　　体力 %d/%d　　货币 %d　　暂存区 %d 件　　%s%s%s" % [
		t.clock.total,
		str(extract_near["steps"]) if int(extract_near["id"]) >= 0 else "—",
		str(rest["steps"]) if int(rest["id"]) >= 0 else "—",
		str(core["steps"]) if int(core["id"]) >= 0 else "—",
		_run.vitality.current, _run.vitality.maximum, _run.wallet.balance, _run.storage.item_count(), _run.faith_line(), _buff_line(), _erosion_line()]


## buff 栏的占位：一行字。局外的和一局里的都列，有时限的写还剩几步
func _buff_line() -> String:
	var parts: Array[String] = []
	for id in _run.meta_buffs:
		var def: RunBuffDef = _run.buff_defs.get(id, null)
		parts.append(def.display_name if def != null else String(id))
	for entry in _run.map_buffs:
		var def: RunBuffDef = _run.buff_defs.get(StringName(String(entry["id"])), null)
		var name := def.display_name if def != null else String(entry["id"])
		parts.append(name + ("（剩 %d 步）" % int(entry["left"]) if int(entry["left"]) > 0 else ""))
	return "　　buff：" + "、".join(parts) if not parts.is_empty() else ""


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


## 右栏：挑出生点阶段每条路线一张卡 —— 这是这一章第一个真正的决策；开局之后收起
func _rebuild_routes() -> void:
	for child in _routes_box.get_children():
		child.queue_free()
	if _run.phase != RunState.Phase.PICK_SPAWN:
		return
	_routes_box.add_child(_label("路线：挑一个出生点", 14, UiPalette.FG))
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
		card.add_theme_font_override("font", font)
		card.add_theme_font_size_override("font_size", 13)
		card.add_theme_color_override("font_color", MapNodeStyle.route_color(i))
		var idx := i
		card.mouse_entered.connect(func(): if _run.phase == RunState.Phase.PICK_SPAWN: _view.bold_route = idx)
		card.mouse_exited.connect(func(): if _run.phase == RunState.Phase.PICK_SPAWN: _view.bold_route = -1)
		card.pressed.connect(func(): pick_spawn(entry))
		_routes_box.add_child(card)
#endregion


#region 界面
func _build() -> void:
	_backdrop()
	var row := _hbox(0)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	var mid := _vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var side := _panel(12)
	side.custom_minimum_size.x = SIDE_WIDTH
	row.add_child(side)
	var col := _vbox(8)
	side.add_child(col)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26      # 右上角是 DevNav 的按钮
	col.add_child(spacer)
	_status = _wrapped("", 12, UiPalette.DIM, SIDE_WIDTH - 30)
	col.add_child(_status)
	var buttons := _hbox(6)
	buttons.add_child(_button("背包（B）", toggle_bag, 13))
	_extract_btn = _button("撤离", func(): extract(), 13)
	_extract_btn.disabled = true
	buttons.add_child(_extract_btn)
	col.add_child(buttons)
	col.add_child(_button("存档并回主菜单", func(): flow.save_and_quit(), 12))
	col.add_child(HSeparator.new())
	_routes_box = _vbox(6)
	col.add_child(_routes_box)
	col.add_child(HSeparator.new())
	col.add_child(_label("日志", 14, UiPalette.FG))
	_log = _log_box(12)
	col.add_child(_log)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_B:
			if _confirm == null and _step_confirm == null:
				toggle_bag()
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
#endregion
