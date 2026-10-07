## 地图屏（M6）：一局的主屏。挑出生点 → 点相邻的点走一步 → 事件由 [GameFlow] 排成叠层一屏一屏来 → 撤离。
##
## 它是当年地图沙盒（M3-6 → M5，066 删了）的正式版：同一个 [MapView]，同一份 HUD，日志在右栏；沙盒的换种子 / 重开 / 读档在这里没有，
## 那些是开局屏与主菜单的事。「背包」把整理面板叠在地图上，随时开；撤离按钮只在撤离点上亮。
## 所有动作都是公开方法，鼠标只是调它们；测试直接调。
extends GameScreen

const InventoryPanelScript := preload("res://ui/game/inventory_panel.gd")
const SettingsScreenScript := preload("res://ui/game/settings_screen.gd")
const EncyclopediaScreenScript := preload("res://ui/game/encyclopedia_screen.gd")
const SIDE_WIDTH := 400     # 090：右栏三个按键放大到 300%，栏也加宽

var _run: RunState = null
var _view: MapView
var _hud: Label
## 092：非常显眼的全局倒计时（地图顶上一行大字）
var _countdown: Label = null
## 087：信仰那一句单独一个标签，停上去开悬浮窗（具体效果、信力怎么涨）
var _faith_hud: Label
var _preview: Label
var _enemy_line: Label
var _status: Label
var _routes_box: VBoxContainer
var _log: RichTextLabel
var _extract_btn: Button
var _reopen_btn: Button
var _skills_box: VBoxContainer
var _tip: HoverTip = null
var _bag: Control = null
var _bag_panel: Control = null
var _confirm: Control = null
## 090（作者定）：地图上按 Esc 呼出的暂停菜单（继续 / 设置 / 存档并回主菜单）；设置嵌在它里面，返回回暂停菜单、一局还在
var _pause: Control = null
var _pause_settings: Control = null
## 114：暂停菜单里嵌着的百科
var _pause_book: Control = null
## 091（作者定 10.2 第 3 条）：「本图规则」卡 —— 第一次进这一章弹出来（局外记住看过了），暂停菜单里能再看
var _rules: Control = null
var _rules_first: bool = false


func open(_payload: Dictionary) -> void:
	_run = flow.run
	_build()
	_adopt()
	if flow.rules_card_pending():
		show_rules(true)     # 091：第一次进这一章：本图规则卡


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


## 走一步。087 起地上按点保留（走了东西留在那个点上、回来能拿），109（作者定）：不再弹「地上还有东西」的提示，直接走
func step(to_id: int) -> bool:
	_view.clear_hover()     # 反馈：进点后悬浮窗一直挂着 —— 走之前收起，鼠标再动才按新位置重算
	return flow.step_to(to_id)


## 在撤离点上按「撤离」：先确认 —— 付多少钱、地上有什么带不出去（3.4）。返回 false = 不在撤离点上
func extract() -> bool:
	var node := _run.current_node()
	if node == null or _run.phase != RunState.Phase.ON_MAP or NodeEvents.effective_type(node) != &"extract":
		_say("撤不了：不在撤离点上")
		return false
	if _countdown_closed(node):
		_say("撤不了：这个撤离点已经关闭（倒计时过半）")
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
		col.add_child(_wrapped("地上还有 %d 件（值 %d 币%s）不会带出去 —— 地上不参战也不出关（3.4）。想带走先放进棋盘（B）" % [
			left, left_value, "，其中 %d 件稀有以上" % rare if rare > 0 else ""], 14, UiPalette.STAMINA, 480))
	var buttons := _hbox(8)
	var go := _button("确定撤离", func(): confirm_extract(), 14)
	go.disabled = not affordable
	buttons.add_child(go)
	buttons.add_child(_button("再想想", cancel_extract, 14, UiPalette.Tier.MINOR))
	col.add_child(buttons)


## 背包整理面板叠在地图上，再按一次收起。084：是能拖着走的浮窗，关掉再开还在上次放的位置
func toggle_bag() -> void:
	if _bag != null:
		_bag.hide()     # 134：先藏起来 —— 这一帧里它的拖拽层就不再算「接地上的面板」
		_bag.queue_free()
		_bag = null
		return
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_bag = shade
	var win := FloatingWindow.new()
	win.setup("bag", "背包", font, toggle_bag, "收起（B）")
	shade.add_child(win)
	_reserve_ground(win)     # 128：背包浮窗占着的地方，地上的东西让开
	var inv := InventoryPanelScript.new()
	inv.setup(_run, font)
	win.body().add_child(inv)
	_bag_panel = inv


func bag_open() -> bool:
	return _bag != null


## 134：开着的背包浮窗里那块面板（没开 null）
func bag_panel() -> Control:
	return _bag_panel if _bag != null and is_instance_valid(_bag_panel) else null


## 134（作者定）：地上双击 —— 背包开着就交给背包面板；没开就进包并打开背包（放不下只开背包、面板里提示）
func ground_double_clicked(uid: int) -> bool:
	if _bag != null or _confirm != null or _pause != null or _rules != null:
		return false
	return _ground_to_bag(uid, func():
		if _bag == null:
			toggle_bag()
		return bag_panel())


## 084：还没走，重新打开这个点的最后一个界面（没拿完的战利品 / 还开着的搜索或商店 / 等着的事件或一场）。没有可开的返回 false
func reopen() -> bool:
	if _bag != null or _confirm != null or _pause != null or _rules != null:
		return false
	_view.clear_hover()
	var ok := flow.reopen_node()
	if not ok:
		_say("这个点上没有可以再打开的界面")
	return ok


func can_reopen() -> bool:
	return flow.can_reopen()


## 090（作者定）：Esc —— 开着什么就关什么（暂停菜单里的设置 → 暂停菜单 → 撤离确认 → 背包）；
## 什么都没开着就呼出暂停菜单。地图上的 Esc 总有事做
func escape() -> bool:
	if _rules != null:
		close_rules()
		return true
	if _pause_book != null:
		close_pause_encyclopedia()
		return true
	if _pause_settings != null:
		close_pause_settings()
		return true
	if _pause != null:
		toggle_pause()
		return true
	if _confirm != null:
		cancel_extract()
		return true
	if _bag != null:
		toggle_bag()
		return true
	toggle_pause()
	return true


## 090：暂停菜单开 / 关：继续（Esc）、设置、存档并回主菜单。开着的时候地图不响应点与快捷键
func toggle_pause() -> void:
	if _pause != null:
		close_pause_settings()
		close_pause_encyclopedia()
		_pause.queue_free()
		_pause = null
		return
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_pause = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := _panel(28)
	center.add_child(panel)
	var col := _vbox(12)
	panel.add_child(col)
	col.add_child(_label("暂停", 26, UiPalette.FG))
	col.add_child(_wrapped("一局还在：搜索 / 商店 / 没拿完的战利品都留在原地", 12, UiPalette.DIM, 360))
	col.add_child(_button("继续（Esc）", toggle_pause, 14, UiPalette.Tier.PRIMARY))
	col.add_child(_button("设置", pause_settings, 14))
	col.add_child(_button("百科", func(): pause_encyclopedia(), 14))     # 114
	if _run != null and _run.chapter != null and not _run.chapter.rules.is_empty():
		col.add_child(_button("本图规则", func(): show_rules(), 14))     # 091：再看一遍规则卡
	col.add_child(_button("存档并回主菜单", func(): flow.save_and_quit(), 14))


func pause_open() -> bool:
	return _pause != null


## 090：暂停菜单里的「设置」：设置屏嵌进暂停菜单（它的「返回」回暂停菜单，不回主菜单 —— 一局还在）
func pause_settings() -> void:
	if _pause == null or _pause_settings != null:
		return
	var s = SettingsScreenScript.new()
	s.screen = GameFlow.Screen.SETTINGS
	s.flow = flow
	s.font = font
	s.back = close_pause_settings
	_pause.add_child(s)
	s.open({})
	_pause_settings = s


func close_pause_settings() -> void:
	if _pause_settings != null:
		_pause_settings.queue_free()
		_pause_settings = null
	refresh_backdrop()     # 091：设置里可能换了底色


func settings_open() -> bool:
	return _pause_settings != null


## 114：暂停菜单里的「百科」：和设置同款嵌法（「返回」回暂停菜单；Esc 先关它）
func pause_encyclopedia(page: String = "") -> void:
	if _pause == null or _pause_book != null:
		return
	var s = EncyclopediaScreenScript.new()
	s.screen = GameFlow.Screen.ENCYCLOPEDIA
	s.flow = flow
	s.font = font
	s.back = close_pause_encyclopedia
	_pause.add_child(s)
	s.open({"page": page} if page != "" else {})
	_pause_book = s


func close_pause_encyclopedia() -> void:
	if _pause_book != null:
		_pause_book.queue_free()
		_pause_book = null


func encyclopedia_open() -> bool:
	return _pause_book != null


## 091：「本图规则」卡：章节写的 ≤ 3 条，一页；[param first] = 第一次进这一章弹的（关掉时记住看过了）
func show_rules(first: bool = false) -> void:
	if _rules != null or _run == null or _run.chapter == null or _run.chapter.rules.is_empty():
		return
	_rules_first = first
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.07, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_rules = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := _panel(28)
	center.add_child(panel)
	var col := _vbox(12)
	panel.add_child(col)
	col.add_child(_label("本图规则　%s" % Names.of(_run.chapter), 24, UiPalette.FG))
	var ctx := TextTemplate.context_for(_run)     # 112：规则卡也过占位符（{item:…} 按稀有度上色）
	for i in _run.chapter.rules.size():
		col.add_child(_rich_line("%d. %s" % [i + 1, UiPalette.resolve_styles(TextTemplate.render(_run.chapter.rules[i], ctx))], 15, 560))
	col.add_child(_wrapped("暂停菜单（Esc）里能再看", 12, UiPalette.DIM, 560))
	col.add_child(_button("知道了（Esc）", close_rules, 14, UiPalette.Tier.PRIMARY))


## 规则卡上的一条（BBCode，自动换行、高度随内容）
func _rich_line(bbcode: String, font_size: int, width: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size.x = width
	UiTheme.rich(r, font_size)
	r.text = bbcode
	return r



func close_rules() -> void:
	if _rules == null:
		return
	_rules.queue_free()
	_rules = null
	if _rules_first:
		_rules_first = false
		flow.mark_rules_seen()


func rules_open() -> bool:
	return _rules != null
#endregion


#region 接线：RunState 与 NodeEvents 的信号写进日志
func _adopt() -> void:
	_view.graph = _run.map
	_view.current_id = _run.travel.current_id if _run.phase != RunState.Phase.PICK_SPAWN else -1
	_view.reachable = {}
	_view.bold_route = -1
	_view.spawn_mask = _run.phase == RunState.Phase.PICK_SPAWN     # 096：挑出生点时全图蒙灰，只露出生点
	_run.travel.moved.connect(_on_moved)
	_run.travel.waited.connect(func(actions: int):
		_note("　原地耗了 %d 个行动点" % actions)
		_after_move())
	_run.travel.refused.connect(func(_i: MoveIntent, why: String): _say("走不了：" + why))
	_run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh_hud())
	_run.vitality.changed.connect(func(_c: int, _m: int, _d: int, _r: StringName): _refresh_hud())
	_run.storage.changed.connect(_refresh_hud)
	_run.encumbrance_changed.connect(func(lv: int):     # 129
		_refresh_hud()
		if _run.encumbrance != null:
			_note("负重变成「%s」%s" % [_run.encumbrance.name_of(lv), "：" + _run.encumbrance.effect_text(lv) if lv > 0 else ""]))
	var buff_mod := BuffModule.of(_run)     # 101：一局里拿到的 buff 在模块里
	if buff_mod != null:
		buff_mod.buffs_changed.connect(_refresh_hud)
	# 082：技能按钮与信力
	_run.skills.changed.connect(func():
		_refresh_skills()
		_refresh_hud())
	var countdown := CountdownModule.of(_run)     # 101：倒计时是一局的模块，数与信号都在它身上
	if countdown != null and countdown.penalty_steps() > 0:     # 094：超带换的倒计时
		_note("[color=#f0ad4e]　带入超出预算 %d：倒计时 −%d[/color]" % [countdown.over_value(), countdown.penalty_steps()])
	for note in flow.take_notes():     # 088：开局拿到的特殊道具（望远镜）等通知
		_note("[color=#f0ad4e]　%s[/color]" % note)
	_run.faith_power.changed.connect(func(id: StringName, p: int, tier: int):
		var def: FaithDef = _run.faith_defs.get(id, null)
		_note("　信力（%s）%d，第 %d 阶" % [def.display_name if def != null else String(id), p, tier])
		_refresh_hud())
	_refresh_skills()
	var node_storage := NodeStorageModule.of(_run)     # 101：按点暂存是一局的模块，信号在它身上
	if node_storage != null:
		node_storage.dropped.connect(func(node_id: int, items: Array):
			_note("　离开点 %d：地上的 %s留在了那里（回来能拿）" % [node_id, StorageWarning.describe(items)]))
		node_storage.restored.connect(func(node_id: int, items: Array):
			_note("　回到点 %d：留在这里的 %d 件回到了地上" % [node_id, items.size()]))
	_run.loot_cleared.connect(_after_move)     # 084：没拿的战利品没了（拿完了、或走了），「回到这个点」跟着灰
	var crafting := CraftingModule.of(_run)     # 101：合成是一局的模块
	if crafting != null:
		crafting.done.connect(func(detail: Dictionary):
			for line in detail.get("log", []):
				_note("　" + String(line)))
	# 猎手（071）：进了感知范围提示一句；动了就重画标记；被赶回上一个点。140 R-23：直接接猎手系统
	if _run.hunters != null:
		_run.hunters.sensed.connect(func(h: Hunter):
			var def: HunterDef = _run.hunters.def_of(h)
			var seen := _run.hunters.visible_hunters().has(h)
			_note("[color=#d9534f]　附近有动静……%s[/color]" % ("（" + def.display_name + "）" if def != null and seen else "")))
		_run.hunters.changed.connect(_refresh_hunter_marks)
		_run.hunters.player_expelled.connect(func(to: int):
			_note("[color=#d9534f]　被赶回了点 %d[/color]" % to)
			_view.current_id = to
			_after_move())
	# 侵蚀（075）：预警、推进、结算了、终局 —— 都写进日志，地图上垫色。直接接侵蚀场
	var field := _run.travel.erosion
	if field != null:
		field.warned.connect(func(band: int, left: int):
			_note("[color=#f0ad4e]　侵蚀预警：第 %d 档还有 %d 步就被侵蚀[/color]" % [band, left])
			_refresh_erosion_view())
		field.advanced.connect(func(bands: int):
			_note("[color=#d9534f]　侵蚀推进：最外 %d 档已被侵蚀[/color]" % (bands + 1))
			_refresh_erosion_view()
			_refresh_hud())
		field.applied.connect(func(node: MapNode, detail: Dictionary):
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
		field.total_reached.connect(func(): _note("[color=#d9534f]　全图都被侵蚀了：快撤[/color]"))
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
	ev.battle_skipped.connect(func(n: MapNode): _note("　溜走了：点 %d 那一场没打" % n.id))     # 136：脱身
	ev.battle_finished.connect(func(n: MapNode, result: BattleResult, won: bool):
		var who := enemy_preview(n.id).get_slice("　", 0)
		_note("　打 %s：%s，%.1f 秒" % [who if who != "" else "敌人", "赢了" if won else ("平局，按输算" if result.is_draw() else "输了"), result.duration_sec()]))
	ev.search_closed.connect(func(_n: MapNode, _haul: GridInventory, why: StringName): _note("　" + search_end_text(why)))
	ev.rested.connect(func(_n: MapNode, got: int): _note("　休息：体力 +%d" % got))
	ev.extract_reached.connect(func(_n: MapNode, fee: int):
		_note("　到了撤离点%s：按「撤离」结束这一局" % ("（付费：%d 币，%s）" % [fee, "付得起" if _run.wallet.can_afford(fee) else "钱不够"] if fee > 0 else "")))
	_run.phase_changed.connect(func(_p: int, why: StringName):
		if why == &"time_out":
			_note("[color=#d9534f]　倒计时归零：行动失败。保险箱里的照样带出[/color]")
		_view.spawn_mask = _run.phase == RunState.Phase.PICK_SPAWN     # 096：挑完出生点遮罩撤掉
		_refresh_hud()
		_refresh_skills())     # 挑完出生点技能才能用：按钮跟着阶段亮
	if countdown != null:
		countdown.notice.connect(func(text: String): _note("[color=#d9534f]　" + text + "[/color]"))     # 092
	var safe := SafeModule.of(_run)     # 101：保险箱是一局的模块，信号在它身上
	if safe != null:
		safe.closed.connect(func(n: int): _note("[color=#c8a2ff]　保险箱关上了：%d 件送回基地，不能再改[/color]" % n))
	var altar := AltarModule.of(_run)     # 101：神坛是一局的模块，信号在它身上
	if altar != null:
		altar.noted.connect(func(text: String):
			_note("[color=#f0ad4e]　" + text + "[/color]")
			_refresh_hud())     # 093
		altar.item_blessed.connect(func(_i: ItemInstance, _f: StringName): _refresh_hud())     # 095
	_rebuild_routes()
	_after_move()
	if _run.phase == RunState.Phase.PICK_SPAWN:
		_say("%s　种子 %d：%d 个点。挑一个出生点（绿圈的「生」）开始" % [
			_run.chapter.display_name, _run.run_seed, _run.map.node_count()])
	else:
		_say("%s　种子 %d：在点 %d 上（三角标是你），行动点 %d。点相邻的点走一步；B 开背包" % [
			_run.chapter.display_name, _run.run_seed, _run.travel.current_id, _run.travel.clock.total])


func _on_moved(intent: MoveIntent, first_visit: bool) -> void:
	_view.current_id = intent.to_id
	var n := _run.map.get_node(intent.to_id)
	var what: String = MapNodeStyle.of(n.type)["label"]
	if intent.kind == MoveIntent.TELEPORT:
		_note("[color=#b38cff]⇢ %d %s，传送（花 %d 点）%s[/color]" % [intent.to_id, what, _run.travel.last_cost, "" if first_visit else "，这里用过了"])
	else:
		_note(("→ %d %s（花 %d 点）" if first_visit else "→ %d %s，穿行（花 %d 点，这里用过了）") % [intent.to_id, what, _run.travel.last_cost])
	var cd := CountdownModule.of(_run)
	if cd != null and cd.has_countdown() and cd.left() > 0 and cd.left() <= 5:
		_note("[color=#d9534f]　倒计时只剩 %d 步！[/color]" % cd.left())
	_after_move()


## 侵蚀在地图上：被侵蚀的档垫色、快被侵蚀的那一档闪红环
func _refresh_erosion_view() -> void:
	if _run == null or _view == null:
		return
	var f: ErosionField = _run.travel.erosion if _run.travel != null else null
	if f == null:
		_view.erosion = {}
		return
	var warn := f.next_band() if f.actions_left() >= 0 and f.actions_left() <= f.mechanic.warn_lead_actions else -1
	_view.erosion = {"eroded": f.eroded_bands, "warn": warn}


## HUD 里的侵蚀一句：没有 / 还没开始 / 侵蚀了几档、下一档几步
func _erosion_line() -> String:
	var f: ErosionField = _run.travel.erosion if _run != null and _run.travel != null else null
	if f == null:
		return ""
	if f.is_total():
		return "　　侵蚀：全图"
	if not f.started():
		return "　　侵蚀：%d 步后开始" % f.actions_left()
	return "　　侵蚀 %d 档（下一档 %d 步）" % [f.eroded_bands + 1, f.actions_left()]


## 134：这个点上看得见的猎手各一行「名字：输了会怎样」—— 被它感知之后才写档（[HunterSystem.loss_hint]）
func _hunter_tip(id: int) -> String:
	if _run == null or _run.hunters == null:
		return ""
	var lines: Array[String] = []
	for h in _run.hunters.visible_hunters():
		if h.node_id != id:
			continue
		var def: HunterDef = _run.hunters.def_of(h)
		var hint := _run.hunters.loss_hint(h)
		lines.append("[color=#d9534f]%s[/color]%s" % [def.display_name if def != null else "?", "　输了会怎样 —— " + hint if hint != "" else ""])
	return "\n".join(lines)


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
	_extract_btn.disabled = node == null or _run.phase != RunState.Phase.ON_MAP or NodeEvents.effective_type(node) != &"extract" or _countdown_closed(node)
	_reopen_btn.disabled = not flow.can_reopen()
	_reopen_btn.tooltip_text = ("重新打开这个点上最后的界面：没拿完的战利品、还开着的搜索或商店。点地图上的当前节点也行" if flow.can_reopen()
		else "这里没有可重开的界面")


func _on_node_pressed(id: int, button: int, _shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT or _bag != null or _confirm != null or _pause != null or _rules != null:
		return
	if _run.phase == RunState.Phase.PICK_SPAWN:
		if not pick_spawn(id):
			_say("先挑一个出生点（绿圈的「生」）")
	elif id == _view.current_id:
		# 090（作者定）：点当前节点 = 打开被收起的界面（同「回到这个点」）
		reopen()
	else:
		step(id)


## 文字再长也不撑宽所在的容器：最小宽度 0、横向铺满、超出裁成省略号
func _pin_width(l: Label) -> void:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 0
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_node_hovered(id: int) -> void:
	_enemy_line.text = enemy_preview(id)
	_update_tooltip(id)
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
	_preview.text = "→ %s　花 %d 行动点%s%s" % [MapNodeStyle.of(n.type)["label"], _run.travel.cost_of(intent),
		"（熟门熟路：这一步不花）" if _run.travel.next_step_free() else ("（负重：双倍）" if _run.travel.action_cost_mult > 1 else ""), "（用过了，只是穿行）" if n.is_visited() else ""]


## 084：节点浮窗（章节开关 `node_tooltips`）：文字按 NodeTooltip 的模板渲染，没用过的战斗点下面画对手的棋盘
func _update_tooltip(id: int) -> void:
	if _tip == null:
		return
	if id < 0 or _bag != null or _confirm != null or _pause != null or not _run.map.has_node(id):
		_tip.hide_tip()
		return
	var node := _run.map.get_node(id)
	var stash := NodeTooltip.stash_text(_run, node)     # 反馈：每个点的地上悬停就能看，不受「节点浮窗」开关管
	var hunt := _hunter_tip(id)     # 134：站在这个点上、看得见的猎手输了会怎样（感知之后才说）
	if hunt != "":
		stash = hunt if stash == "" else stash + "\n" + hunt
	if not flow.tooltips_enabled():
		if stash == "":
			_tip.hide_tip()
		else:
			_tip.show_text(stash, get_global_mouse_position(), null)
		return
	var extra: Control = null
	if NodeTooltip.shows_board(node):
		var v := InventoryView.new()
		v.label_font = font
		v.inventory = EnemyKit.board_of(node.content, flow.items)
		extra = v
	# 101 第 5 刀：浮窗文字里的样式码（`{c:hp}`）在这里换成真颜色 —— 颜色表是界面的事
	var text := UiPalette.resolve_styles(NodeTooltip.text_for(_run, _run.chapter, node))
	_tip.show_text(text + ("\n" + stash if stash != "" else ""), get_global_mouse_position(), extra)


func tooltip_text() -> String:
	return _tip.text() if _tip != null and _tip.is_showing() else ""


## 这个点里的敌人一行摘要（5.10：全图可见）；没有敌人就是空串
## 135：搜索结束那一句日志按原因说人话（遭遇打输 / 搜满 / 自己走）
static func search_end_text(why: StringName) -> String:
	match why:
		&"encounter":
			return "被赶跑，这个点不能再搜"
		&"exhausted":
			return "搜完了"
		&"slipped":
			return "溜走了，这个点不能再搜"
	return "离开"


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
			DropResolver.expected_count(content, _run.drop_rule, ctx, flow.items, _run.map.get_node(id).type == &"core"),
			DropResolver.treasure_chance(_run.drop_rule, ctx) * 100.0]
	if _run.economy != null:
		var depth: float = EnemyPlacer.depths_of(_run.map).get(id, 0.0)
		line += "　打赢 +%d 币" % _run.economy.battle_reward(int(content.get("strength", 0)), depth, _run.chapter.difficulty)
	return line


## 129：顶栏的负重小标：轻装不画；吃力 / 超重 / 寸步难行，走路翻倍的那一级再注一句
func _encumbrance_tag() -> String:
	var lv := _run.encumbrance_level()
	if lv <= 0 or _run.encumbrance == null:
		return ""
	var tag := "负重：" + _run.encumbrance.name_of(lv)
	var mult := _run.encumbrance.travel_mult_of(lv)
	if mult > 1:
		tag += "（走一步花 %d 倍）" % mult
	return tag


func _refresh_hud() -> void:
	if _run == null or _hud == null:
		return
	_refresh_countdown()
	if _run.phase == RunState.Phase.PICK_SPAWN:
		_hud.text = "行动点 —　　挑出生点　　体力 %d/%d　　货币 %d　　地上 %d 件" % [
			_run.vitality.current, _run.vitality.maximum, _run.wallet.balance, _run.storage.item_count()]
		return
	var t := _run.travel
	var extract_near := MapNavigator.nearest_of_type(_run.map, t.current_id, &"extract")
	var rest := MapNavigator.nearest_of_type(_run.map, t.current_id, &"rest")
	var core := MapNavigator.nearest_of_type(_run.map, t.current_id, &"core")
	_hud.text = "行动点 %d　　距最近撤离点 %s 步　　距最近休息区 %s 步　　距核心 %s 步　　体力 %d/%d　　货币 %d　　地上 %d 件　　" % [
		t.clock.total,
		str(extract_near["steps"]) if int(extract_near["id"]) >= 0 else "—",
		str(rest["steps"]) if int(rest["id"]) >= 0 else "—",
		str(core["steps"]) if int(core["id"]) >= 0 else "—",
		_run.vitality.current, _run.vitality.maximum, _run.wallet.balance, _run.storage.item_count()]
	_hud.text += _encumbrance_tag()
	if _faith_hud != null:
		_faith_hud.text = _run.faith_line() + _power_line() + _buff_line() + _erosion_line()


## 这个撤离点被倒计时关掉了没（没装倒计时模块 = 不会关）
func _countdown_closed(node: MapNode) -> bool:
	var cd := CountdownModule.of(_run)
	return cd != null and cd.extract_closed(node)


## 092：倒计时那一行大字 + 地图上关闭中的撤离点的标记
func _refresh_countdown() -> void:
	if _countdown == null:
		return
	var box := _countdown.get_parent() as Control
	var cd := CountdownModule.of(_run)
	if cd == null or not cd.has_countdown():
		box.visible = false
		_view.closing = {}
		return
	box.visible = true
	var left := cd.left()
	var limit := cd.limit()
	var text := "倒计时 %d / %d" % [left, limit]
	var closing := cd.closing_extract_id()
	if closing >= 0:
		var node := _run.map.get_node(closing)
		var closed := cd.extract_closed(node)
		text += "　　撤离点 %d %s" % [closing, "已关闭" if closed else "剩 %d 步关闭" % (left - PaidExtracts.closes_at(node))]
		_view.closing = {"id": closing, "closed": closed, "left": left - PaidExtracts.closes_at(node)}
	else:
		_view.closing = {}
	_countdown.text = text
	var ratio := float(left) / float(maxi(limit, 1))
	var col := UiPalette.HP if (ratio <= 0.25 or left <= 5) else (UiPalette.STAMINA if ratio <= 0.5 else UiPalette.FG)
	_countdown.add_theme_color_override("font_color", col)     # 121 特例：颜色随剩余回合实时变（过半琥珀、四分之一红），不是固定样式
	var style := (box as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = col



## 信力一句（082）：「　信力 12 / 30（第 1 阶）」；没激活信仰不显示
func _power_line() -> String:
	var line := _run.faith_power.line() if _run.faith_power != null else ""
	return "　" + line if line != "" else ""


## 局内技能（082）：一个技能一个按钮，能用的亮着；被动的不占按钮
func _refresh_skills() -> void:
	if _skills_box == null or _run == null:
		return
	for c in _skills_box.get_children():
		c.queue_free()
	if _run.skills == null:
		return
	for s in _run.skills.active_skills():
		var d := s as RunSkill
		var bits: Array[String] = []
		if _run.skills.is_armed(d.id):
			bits.append("已准备")
		if _run.skills.uses_of(d.id) >= 0:
			bits.append("剩 %d 次" % _run.skills.uses_of(d.id))
		if _run.skills.cooldown_of(d.id) > 0:
			bits.append("冷却 %d 步" % _run.skills.cooldown_of(d.id))
		var btn := _button("%s%s" % [d.display_name, ("（" + "，".join(bits) + "）") if not bits.is_empty() else ""], func(): use_skill(d.id), 13, UiPalette.Tier.MINOR)
		btn.disabled = _run.skills.can_use(d.id) != "" or not d.map_usable()
		btn.tooltip_text = d.summary() + ("\n" + Names.description_of(d) if d.description != "" else "") + ("" if d.map_usable() else "\n在战前准备屏（或猎手面前）用")
		_skills_box.add_child(btn)
	if _run.skills.evading():
		_skills_box.add_child(_label("躲避中（剩 %d 步）" % _run.skills.evade_left, 12, UiPalette.DIM))


## 用一个技能。用不了把原因写在状态栏；用了写进日志
func use_skill(id: StringName) -> bool:
	var why := flow.use_skill(id)
	if why != "":
		_say(why)
		return false
	var d := _run.skills.skill(id)
	_note("　用了「%s」：%s" % [d.display_name if d != null else String(id), d.describe() if d != null else ""])
	_refresh_skills()
	_refresh_hud()
	return true


## buff 栏的占位：一行字。局外的和一局里的都列，有时限的写还剩几步
func _buff_line() -> String:
	var parts: Array[String] = []
	for id in _run.meta_buffs:
		var def: RunBuffDef = _run.buff_defs.get(id, null)
		parts.append(def.display_name if def != null else String(id))
	for entry in BuffModule.entries_of(_run):
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
		card.add_theme_font_size_override("font_size", 13)
		card.add_theme_color_override("font_color", MapNodeStyle.route_color(i))     # 121 特例：路线色和地图上画的那条线同色（画布色）
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
	# 092（作者定）：全局倒计时 —— 顶上一行大字，颜色随剩余变（过半琥珀、四分之一以下红）
	_countdown = _label("", 34, UiPalette.FG)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cd_box := PanelContainer.new()
	var cd_style := StyleBoxFlat.new()
	cd_style.bg_color = UiPalette.PANEL
	cd_style.border_color = UiPalette.STAMINA
	cd_style.set_border_width_all(2)
	cd_style.set_content_margin_all(6)
	cd_box.add_theme_stylebox_override("panel", cd_style)     # 121 特例：边框色随倒计时实时改（见 _refresh_countdown），得是这一块自己的底
	cd_box.add_child(_countdown)
	cd_box.visible = false
	mid.add_child(cd_box)
	_reserve_ground(cd_box)     # 128
	_hud = _label("", 14, UiPalette.FG)
	var hud_box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = UiPalette.PANEL
	st.set_content_margin_all(8)
	hud_box.add_theme_stylebox_override("panel", st)     # 121 特例：信力 / 行动点那条 HUD 的无边窄底，只此一处
	var hud_row := _hbox(0)
	hud_row.add_child(_hud)
	_faith_hud = _label("", 14, UiPalette.FG)
	_faith_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	_faith_hud.mouse_entered.connect(func():
		if _tip != null and _run != null:
			_tip.show_text(FaithTooltip.describe(_run.active_faith(), _run.faith_power, flow.items), _faith_hud.global_position + Vector2(0, _faith_hud.size.y)))
	_faith_hud.mouse_exited.connect(func():
		if _tip != null:
			_tip.hide_tip())
	hud_row.add_child(_faith_hud)
	hud_box.add_child(hud_row)
	mid.add_child(hud_box)
	_reserve_ground(hud_box)     # 128
	_view = MapView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.node_pressed.connect(_on_node_pressed)
	_view.node_hovered.connect(_on_node_hovered)
	_view.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and _tip != null:
			_tip.follow(get_global_mouse_position()))     # 084：浮窗跟着鼠标走，和道具悬浮窗一样
	mid.add_child(_view)
	# 反馈（bug：悬停节点时地图错位、闪烁）：这两行的文字随悬停的点变长变短，Label 的最小宽度跟着文字走，
	# 把中间这一列撑宽 → 地图视图被挤窄 → 触发 resized 重新居中 → 地图位移、鼠标脱离节点 → 文字清空又缩回去 → 再悬停，如此往复。
	# 让它们不参与布局宽度（超长就省略号裁掉），悬停就不会再改变地图的尺寸
	_preview = _label("", 13, UiPalette.FG)
	_preview.custom_minimum_size.y = 22
	_pin_width(_preview)
	mid.add_child(_preview)
	_enemy_line = _label("", 13, UiPalette.DIM)
	_enemy_line.custom_minimum_size.y = 22
	_pin_width(_enemy_line)
	mid.add_child(_enemy_line)
	_tip = HoverTip.new(font)
	add_child(_tip)

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
	# 090（作者定）：右栏的三个互动按键放大到 300%，竖着排
	var buttons := _vbox(6)
	buttons.add_child(_button("背包（B）", toggle_bag, 13, UiPalette.Tier.PRIMARY))
	_reopen_btn = _button("回到这个点（N）", func(): reopen(), 13, UiPalette.Tier.PRIMARY)
	_reopen_btn.disabled = true
	_reopen_btn.tooltip_text = "还没走的时候，重新打开这个点上最后的界面：没拿完的战利品、还开着的搜索或商店。点地图上的当前节点也行"
	buttons.add_child(_reopen_btn)
	_extract_btn = _button("撤离", func(): extract(), 13, UiPalette.Tier.PRIMARY)
	_extract_btn.disabled = true
	buttons.add_child(_extract_btn)
	col.add_child(buttons)
	_skills_box = _vbox(4)
	col.add_child(_skills_box)
	col.add_child(_button("存档并回主菜单", func(): flow.save_and_quit(), 12, UiPalette.Tier.MINOR))
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
			if _confirm == null and _pause == null and _rules == null:
				toggle_bag()
		KEY_N:
			reopen()
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
