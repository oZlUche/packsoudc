## 地图屏（M6）：一局的主屏。挑出生点 → 点相邻的点走一步 → 事件由 [GameFlow] 排成叠层一屏一屏来 → 撤离。
##
## 它是当年地图沙盒（M3-6 → M5，066 删了）的正式版：同一个 [MapView]，同一份 HUD；沙盒的换种子 / 重开 / 读档在这里没有，
## 那些是开局屏与主菜单的事。「背包」把整理面板叠在地图上，随时开。
## 所有动作都是公开方法，鼠标只是调它们；测试直接调。
## 150 补 1：原来的右栏没了 —— 按钮、技能、路线、调试台箭头都是这一屏的「部件」（[method hud_part]），装进读数层的组件里按布局摆。
## 166（作者定）：地图铺满整屏，读数浮在上面（顶端栏、左下图例与路线、右下腰带；地图按 [method HudHost.content_inset] 躲开它们）；
## 背包 / 放大镜 / 主动技能是顶端栏右槽的图标按钮；撤离按钮删了（撤离点的事件屏里有「撤离」），「存档并回主菜单」删了（进点自动存档，
## 暂停菜单「回主菜单」前静默存一次）；日志与「地上 N 件」挪进调试台，调试台盖在地图上、顶缘在顶端栏下面；序章开头的静态教程（[CoachOverlay]）
extends GameScreen

const SettingsScreenScript := preload("res://ui/game/settings_screen.gd")
const EncyclopediaScreenScript := preload("res://ui/game/encyclopedia_screen.gd")
## 路线卡片的宽（左下角）
const PART_WIDTH := 300
## 166：地图底下浮着的预览几行（走过去花多少、敌人一行）
const PREVIEW_LINES := 2
const REOPEN_HINT := "再看一眼脚下这个点：没拿完的战利品、还开着的搜索或商店。点地图上的当前节点也行"
## 调试台里日志那一块的高
const LOG_HEIGHT := 220

var _run: RunState = null
var _view: MapView
## 150（作者定）：顶上的读数（倒计时、行动点、体力、货币、信仰……）都是能摆放的组件，按布局文件摆在地图那一块上
var _hud_host: HudHost
## 150：调试台抽屉（139 那个），里面是「摆读数」
var _drawer: DevDrawer = null
## 180：调试台里的「下局种子」
var _next_seed: SpinBox = null
## 抽屉离右缘的空（[method DevDrawer.dock] 的 margin）
const DRAWER_MARGIN := 12.0
var _hud_edit_btn: Button = null
var _debug_line: Label = null
var _preview: Label
var _enemy_line: Label
var _status: Label
var _routes_box: VBoxContainer
var _log: RichTextLabel
## 166：调试台里的「地上 N 件」
var _ground_line: Label
var _bag_btn: IconButton
var _reopen_btn: IconButton
var _skills_box: HBoxContainer
## 166：序章开头的静态教程（开着时盖在最上面）
var _coach: CoachOverlay = null
## 150 补 1：这一屏交给读数层摆的部件（id → 控件）；没被组件领走的（调试模式关着时的日志）挂在藏着的架子上，照样在
var _parts: Dictionary = {}
var _shelf: Control = null
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
## 180 §4：入局转场 —— 从开局第三页的预览拉近到这张图（[method begin_reveal]）。总长、各段起止（秒）
const REVEAL_SEC := 1.4
const REVEAL_PAPER := Vector2(0.0, 0.5)
const REVEAL_CAMERA := Vector2(0.2, 1.0)
const REVEAL_NODES := Vector2(0.5, 1.2)
const REVEAL_DECO := Vector2(0.6, 1.3)
const REVEAL_HUD := Vector2(1.2, 1.35)
## 转场里盖在地图上的那张纸（圆里透明、越化越大），没在转场 = null
var _paper: Control = null
## 转场的起止：{zoom0, pan0, zoom1, pan1, r0, r1, levels}；空 = 没在转场
var _reveal: Dictionary = {}
var _reveal_tween: Tween = null
## 浮在地图上的读数与预览两行：转场最后才出来
var _floating: Array[Control] = []


func open(payload: Dictionary) -> void:
	_run = flow.run
	_build()
	_adopt()
	var reveal: Dictionary = payload.get("reveal", {})
	if reveal_allowed(reveal):
		begin_reveal(reveal)     # 180：规则卡、教程等转场完再放
		return
	_after_open()


func _after_open() -> void:
	if flow.rules_card_pending():
		show_rules(true)     # 091：第一次进这一章：本图规则卡
	_maybe_coach.call_deferred()     # 166：开场没有事件压着就直接放


func refresh() -> void:
	_after_move()


#region 公开动作
## 182：新的一局在开局第三页就挑好了出生点、直接站在上面；这条路只留给停在挑出生点阶段的旧存档（与不经开局屏的直开）一版
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
	var ok := flow.step_to(to_id)
	if not ok and _run != null and (_run.phase != RunState.Phase.ON_MAP or not _run.events.pending_battle.is_empty()):
		say(UiText.t("notice.busy"))     # 186：等着开打 / 不在图上（旅程不发 refused）
	return ok


## 在撤离点上按「撤离」：先确认 —— 付多少钱、地上有什么带不出去（3.4）。返回 false = 不在撤离点上
func extract() -> bool:
	var node := _run.current_node()
	if node == null or _run.phase != RunState.Phase.ON_MAP or NodeEvents.effective_type(node) != &"extract":
		say(UiText.t("notice.not_extract"))
		return false
	if _countdown_closed(node):
		say(UiText.t("notice.extract_closed"))
		return false
	_open_confirm(node)
	return true


## 确认撤离。付不起返回 false，留在地图上
func confirm_extract() -> bool:
	cancel_extract()
	var node := _run.current_node()
	if not flow.extract():
		say(UiText.t("notice.extract_fee") % (_run.events.extract_fee(node) if node != null else 0))
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
	_confirm = _shade(0.7, true)
	var panel := _modal_panel("撤离？", 20)
	panel.custom_minimum_size.x = 520
	_confirm.get_child(0).add_child(panel)
	var col := _vbox(10)
	panel.content.add_child(col)
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
	_bag = _shade(0.7)
	var win := FloatingWindow.new()
	win.setup("bag", "背包", toggle_bag, "收起（B）")
	_bag.add_child(win)
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
		say(UiText.t("notice.nothing_to_reopen"))
	return ok


func can_reopen() -> bool:
	return flow.can_reopen()


## 090（作者定）：Esc —— 开着什么就关什么（暂停菜单里的设置 → 暂停菜单 → 撤离确认 → 背包）；
## 什么都没开着就呼出暂停菜单。地图上的 Esc 总有事做
func escape() -> bool:
	if _coach != null:
		_coach.next()     # 166：Esc 也是下一步
		return true
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
	_pause = _shade(0.72, true)
	var panel := _modal_panel("暂停", 28)
	_pause.get_child(0).add_child(panel)
	var col := _vbox(12)
	panel.content.add_child(col)
	col.add_child(_wrapped("一局还在：搜索 / 商店 / 没拿完的战利品都留在原地", 12, UiPalette.DIM, 360))
	col.add_child(_button("继续（Esc）", toggle_pause, 14, UiPalette.Tier.PRIMARY))
	col.add_child(_button("设置", pause_settings, 14))
	col.add_child(_button("百科", func(): pause_encyclopedia(), 14))     # 114
	if _run != null and _run.chapter != null and not _run.chapter.rules.is_empty():
		col.add_child(_button("本图规则", func(): show_rules(), 14))     # 091：再看一遍规则卡
	col.add_child(_button("回主菜单", func(): flow.save_and_quit(), 14))     # 166：进点自动存档；这里回去之前也静默存一次


func pause_open() -> bool:
	return _pause != null


## 090：暂停菜单里的「设置」：设置屏嵌进暂停菜单（它的「返回」回暂停菜单，不回主菜单 —— 一局还在）
func pause_settings() -> void:
	if _pause == null or _pause_settings != null:
		return
	_pause_settings = _embed_in_pause(SettingsScreenScript, GameFlow.Screen.SETTINGS, {}, close_pause_settings)


func close_pause_settings() -> void:
	if _pause_settings != null:
		_pause_settings.queue_free()
		_pause_settings = null
	refresh_backdrop()     # 091：设置里可能换了底色
	apply_debug_mode()     # 150 补 2：设置里可能开关了调试模式


func settings_open() -> bool:
	return _pause_settings != null


## 114：暂停菜单里的「百科」：和设置同款嵌法（「返回」回暂停菜单；Esc 先关它）
func pause_encyclopedia(page: String = "") -> void:
	if _pause == null or _pause_book != null:
		return
	_pause_book = _embed_in_pause(EncyclopediaScreenScript, GameFlow.Screen.ENCYCLOPEDIA, {"page": page} if page != "" else {}, close_pause_encyclopedia)


func close_pause_encyclopedia() -> void:
	if _pause_book != null:
		_pause_book.queue_free()
		_pause_book = null


func encyclopedia_open() -> bool:
	return _pause_book != null


## 090 / 114：把一屏嵌进暂停菜单（设置、百科）：它的「返回」回暂停菜单，不回主菜单 —— 一局还在
func _embed_in_pause(script: GDScript, screen_id: int, payload: Dictionary, on_close: Callable) -> GameScreen:
	var s = script.new()
	s.screen = screen_id
	s.flow = flow
	s.font = font
	s.back = on_close
	_pause.add_child(s)
	s.open(payload)
	return s


## 091：「本图规则」卡：章节写的 ≤ 3 条，一页；[param first] = 第一次进这一章弹的（关掉时记住看过了）
func show_rules(first: bool = false) -> void:
	if _rules != null or _run == null or _run.chapter == null or _run.chapter.rules.is_empty():
		return
	_rules_first = first
	_rules = _shade(0.72, true)
	var panel := _modal_panel("本图规则　%s" % Names.of(_run.chapter), 28)
	_rules.get_child(0).add_child(panel)
	var col := _vbox(12)
	panel.content.add_child(col)
	var ctx := TextTemplate.context_for(_run)     # 112：规则卡也过占位符（{item:…} 按稀有度上色）
	for i in _run.chapter.rules.size():
		col.add_child(UiTheme.rich_block(560, 15, "%d. %s" % [i + 1, TextTemplate.render(_run.chapter.rules[i], ctx)]))
	col.add_child(_wrapped("暂停菜单（Esc）里能再看", 12, UiPalette.DIM, 560))
	col.add_child(_button("知道了（Esc）", close_rules, 14, UiPalette.Tier.PRIMARY))


func close_rules() -> void:
	if _rules == null:
		return
	_rules.queue_free()
	_rules = null
	if _rules_first:
		_rules_first = false
		flow.mark_rules_seen()
	_maybe_coach.call_deferred()     # 166：规则卡收起来才轮到教程


## 反馈：地图缩放全局沿用 —— 记进设置并存盘（0 = 回到自动）
func _remember_zoom(z: float) -> void:
	if flow == null or flow.settings == null:
		return
	flow.settings.map_zoom = GameSettings.normalize_zoom(z)
	flow.save_settings()


func rules_open() -> bool:
	return _rules != null
#endregion


#region 接线：RunState 与 NodeEvents 的信号写进日志
func _adopt() -> void:
	_view.skin = _run.chapter.map_skin if _run.chapter != null else &""     # 每章一张手绘底图
	_view.graph = _run.map
	_view.current_id = _run.travel.current_id if _run.phase != RunState.Phase.PICK_SPAWN else -1
	_open_view()
	_view.reachable = {}
	_view.bold_route = -1
	_view.spawn_mask = _run.phase == RunState.Phase.PICK_SPAWN     # 096：挑出生点时全图蒙灰，只露出生点
	_run.travel.moved.connect(_on_moved)
	_run.travel.waited.connect(func(actions: int):
		_note("　原地耗了 %d 步" % actions)
		_after_move())
	_run.travel.refused.connect(func(_i: MoveIntent, why: String, code: StringName):
		_say("走不了：" + why)     # 开发看的原因（带点号）
		_hud_host.notice(UiText.t("notice.not_adjacent" if code == MapTravel.NOT_ADJACENT else "notice.cannot_move")))     # 186：玩家用语
	var problems: Array[String] = []
	_hud_host.debug = debug_mode()     # 150 补 2
	_hud_host.setup(_run, self, HudLayout.load_for("map", problems))     # 150
	for p in problems:
		_note("[color=#f0ad4e]　读数布局：%s[/color]" % p)
	_run.wallet.changed.connect(func(_b: int, _d: int, _r: StringName): _refresh_hud())
	_run.vitality.changed.connect(func(_c: int, _m: int, _d: int, _r: StringName): _refresh_hud())
	_run.storage.changed.connect(_refresh_hud)
	_run.encumbrance_changed.connect(func(lv: int):     # 129
		_refresh_hud()
		if _run.encumbrance != null:
			_note("负重变成「%s」%s" % [_run.encumbrance.name_of(lv), "：" + _run.encumbrance.effect_text(lv) if lv > 0 else ""])
			_hud_host.notice(UiText.t("notice.encumbrance") % _run.encumbrance.name_of(lv)))
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
			_note("[color=#d9534f]　附近有动静……%s[/color]" % ("（" + def.display_name + "）" if def != null and seen else ""))
			_hud_host.notice(UiText.t("notice.hunter_sensed"), true))
		_run.hunters.changed.connect(_refresh_hunter_marks)
		_run.hunters.player_expelled.connect(func(to: int):
			_note("[color=#d9534f]　被赶回了点 %d[/color]" % to)
			_hud_host.notice(UiText.t("notice.expelled"), true)
			_view.current_id = to
			_after_move())
	# 侵蚀（075）：预警、推进、结算了、终局 —— 都写进日志，地图上垫色。直接接侵蚀场
	var field := _run.travel.erosion
	if field != null:
		field.warned.connect(func(band: int, left: int):
			_note("[color=#f0ad4e]　侵蚀预警：第 %d 档还有 %d 步就被侵蚀[/color]" % [band, left])
			_hud_host.notice(UiText.t("notice.erosion_warned") % left, true)
			_refresh_erosion_view())
		field.advanced.connect(func(bands: int):
			_note("[color=#d9534f]　侵蚀推进：最外 %d 档已被侵蚀[/color]" % (bands + 1))
			_hud_host.notice(UiText.t("notice.erosion_advanced"), true)
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
		field.total_reached.connect(func():
			_note("[color=#d9534f]　全图都被侵蚀了：快撤[/color]")
			_hud_host.notice(UiText.t("notice.erosion_total"), true))
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
		_view.queue_redraw())
	ev.battle_skipped.connect(func(n: MapNode): _note("　溜走了：点 %d 那一场没打" % n.id))     # 136：脱身
	ev.battle_finished.connect(func(n: MapNode, result: BattleResult, won: bool):
		var who := enemy_preview(n.id).get_slice("　", 0)
		_note("　打 %s：%s，%.1f 秒" % [who if who != "" else "敌人", "赢了" if won else ("平局，按输算" if result.is_draw() else "输了"), result.duration_sec()]))
	ev.search_closed.connect(func(_n: MapNode, _haul: GridInventory, why: StringName): _note("　" + search_end_text(why)))
	ev.rested.connect(func(_n: MapNode, got: int): _note("　休息：体力 +%d" % got))
	ev.extract_reached.connect(func(_n: MapNode, fee: int):
		_note("　到了撤离点%s：按「撤离」结束这一局" % ("（付费：%d 币，%s）" % [fee, "付得起" if _run.wallet.can_afford(fee) else "钱不够"] if fee > 0 else ""))
		_hud_host.notice(UiText.t("notice.at_extract_paid") % fee if fee > 0 else UiText.t("notice.at_extract")))
	_run.phase_changed.connect(func(_p: int, why: StringName):
		if why == &"time_out":
			_note("[color=#d9534f]　倒计时归零：行动失败。保险箱里的照样带出[/color]")
		_view.spawn_mask = _run.phase == RunState.Phase.PICK_SPAWN     # 096：挑完出生点遮罩撤掉
		_refresh_hud()
		_refresh_skills())     # 挑完出生点技能才能用：按钮跟着阶段亮
	if countdown != null:
		countdown.notice.connect(func(text: String):
			_note("[color=#d9534f]　" + text + "[/color]")     # 092
			_hud_host.notice(text, true))     # 186：撤离点关了
	var safe := SafeModule.of(_run)     # 101：保险箱是一局的模块，信号在它身上
	if safe != null:
		safe.closed.connect(func(n: int):
			_note("[color=#c8a2ff]　保险箱关上了：%d 件送回基地，不能再改[/color]" % n)
			_hud_host.notice(UiText.t("notice.safe_closed") % n))
	var altar := AltarModule.of(_run)     # 101：神坛是一局的模块，信号在它身上
	if altar != null:
		altar.noted.connect(func(text: String):
			_note("[color=#f0ad4e]　" + text + "[/color]")
			_hud_host.notice(text)     # 186：神坛的话原样（信仰系统生成）
			_refresh_hud())     # 093
		altar.item_blessed.connect(func(_i: ItemInstance, _f: StringName): _refresh_hud())     # 095
	_rebuild_routes()
	_after_move()
	if _run.phase == RunState.Phase.PICK_SPAWN:
		_say("%s　种子 %d：%d 个点。挑一个出生点（绿圈的「生」）开始" % [
			_run.chapter.display_name, _run.run_seed, _run.map.node_count()])
	else:
		_say("%s　种子 %d：在点 %d 上（小兵棋子是你），已走 %d 步。点相邻的点走一步；B 开背包" % [
			_run.chapter.display_name, _run.run_seed, _run.travel.current_id, _run.travel.clock.total])


## 184：走一步的动画（棋子跳、镜头跟）跟着换屏淡入的开关
func _animate_moves() -> bool:
	return GameDirector.fades_allowed and flow.settings != null and flow.settings.ui_fades


func _on_moved(intent: MoveIntent, first_visit: bool) -> void:
	_view.current_id = intent.to_id
	_view.animate_moves = _animate_moves()
	_view.hop_from(intent.from_id, intent.kind == MoveIntent.TELEPORT)     # 184：棋子从旧点跳过来
	var n := _run.map.get_node(intent.to_id)
	var what: String = MapNodeStyle.of(n.type)["label"]
	if intent.kind == MoveIntent.TELEPORT:
		_note("[color=#b38cff]⇢ %d %s，传送（花 %d 点）%s[/color]" % [intent.to_id, what, _run.travel.last_cost, "" if first_visit else "，这里用过了"])
	else:
		_note(("→ %d %s（花 %d 点）" if first_visit else "→ %d %s，穿行（花 %d 点，这里用过了）") % [intent.to_id, what, _run.travel.last_cost])
	var cd := CountdownModule.of(_run)
	if cd != null and cd.has_countdown() and cd.left() > 0 and cd.left() <= 5:
		_note("[color=#d9534f]　倒计时只剩 %d 步！[/color]" % cd.left())
		warn(UiText.t("notice.countdown") % cd.left())
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
	var cost := {}
	var teleport := {}
	if _run.phase == RunState.Phase.ON_MAP:
		for id in _run.travel.available_moves():
			reach[id] = true
			# 184：墨路上的「计二步」与传送签 —— 和悬停预览（129）同一份算法
			var intent := MapNavigator.resolve_step(_run.map, _run.travel.current_id, id)
			cost[id] = _run.travel.cost_of(intent) if intent != null else 1
			if intent != null and intent.kind == MoveIntent.TELEPORT:
				teleport[id] = true
	_view.reachable = reach
	_view.reach_cost = cost
	_view.reach_teleport = teleport
	_view.animate_moves = _animate_moves()
	if not revealing():
		_view.follow_current(_view.animate_moves)     # 184：人出了屏幕中央三分之一就把镜头带回来（缩放不动）
	_view.queue_redraw()
	_refresh_hud()
	_refresh_hunter_marks()
	_reopen_btn.disabled = not flow.can_reopen()
	_reopen_btn.tooltip_text = "放大镜（N）\n" + (REOPEN_HINT if flow.can_reopen() else "这里没有可重开的界面")


func _on_node_pressed(id: int, button: int, _shift: bool) -> void:
	if button != MOUSE_BUTTON_LEFT or _bag != null or _confirm != null or _pause != null or _rules != null:
		return
	if _run.phase == RunState.Phase.PICK_SPAWN:
		if not pick_spawn(id):
			say(UiText.t("notice.pick_spawn"))
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
	# 179：只说步 —— 代价 1 不写，别的写「计 N 步」
	var cost := _run.travel.cost_of(intent)
	_preview.text = "→ %s%s%s%s" % [MapNodeStyle.of(n.type)["label"], "" if cost == 1 or _run.travel.next_step_free() else "　计 %d 步" % cost,
		"（熟门熟路：这一步不计）" if _run.travel.next_step_free() else ("（负重：双倍）" if _run.travel.action_cost_mult > 1 else ""), "（用过了，只是穿行）" if n.is_visited() else ""]


## 084：节点浮窗（章节开关 `node_tooltips`）：文字按 NodeTooltip 的模板渲染，没用过的战斗点下面画对手的棋盘
func _update_tooltip(id: int) -> void:
	if _tip == null:
		return
	if _bag != null or _confirm != null or _pause != null:
		_tip.hide_tip()
		return
	if id < 0 or not _run.map.has_node(id):
		_tip.release()     # 作者 2026-10-17：离开点，钉住的浮窗留着
		return
	var node := _run.map.get_node(id)
	var stash := NodeTooltip.stash_text(_run, node)     # 反馈：每个点的地上悬停就能看，不受「节点浮窗」开关管
	var hunt := _hunter_tip(id)     # 134：站在这个点上、看得见的猎手输了会怎样（感知之后才说）
	if hunt != "":
		stash = hunt if stash == "" else stash + "\n" + hunt
	if not flow.tooltips_enabled():
		if stash == "":
			_tip.release()
		else:
			_tip.show_text(stash, get_global_mouse_position(), null)
		return
	var extra: Control = null
	if NodeTooltip.shows_board(node):
		var v := InventoryView.new()
		v.label_font = font
		v.inventory = EnemyKit.board_of(node.content, flow.items)
		extra = v
	# 101 第 5 刀：浮窗文字里的样式码（`{c:hp}`）—— 169 起由悬浮窗按自己的底换成真颜色（浅纸暗字）
	var text := NodeTooltip.text_for(_run, _run.chapter, node)
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
		line += "　预计掉 %.1f 件，珍宝 %.0f%%" % [
			DropResolver.expected_count(content, _run.drop_rule, ctx, flow.items, _run.map.get_node(id).type == &"core"),
			DropResolver.treasure_chance(_run.drop_rule, ctx) * 100.0]
	if _run.economy != null:
		var depth: float = EnemyPlacer.depths_of(_run.map).get(id, 0.0)
		line += "　打赢 +%d 币" % _run.economy.battle_reward(int(content.get("strength", 0)), depth, _run.chapter.difficulty)
	return line


## 150：读数都在组件里；这里只叫宿主整体刷一遍（组件也各自订了信号），外加地图上撤离点的关闭标记
func _refresh_hud() -> void:
	if _run == null or _hud_host == null:
		return
	_refresh_countdown()
	_hud_host.refresh()
	if _ground_line != null:
		_ground_line.text = "地上 %d 件" % _run.storage.item_count()     # 166：在调试台里

## 092：地图上关闭中的撤离点的标记（倒计时那一行大字是读数组件 `countdown`，150）
func _refresh_countdown() -> void:
	var cd := CountdownModule.of(_run)
	var closing := cd.closing_extract_id() if cd != null and cd.has_countdown() else -1
	if closing < 0:
		_view.closing = {}
		return
	var node := _run.map.get_node(closing)
	_view.closing = {"id": closing, "closed": cd.extract_closed(node), "left": cd.left() - PaidExtracts.closes_at(node)}


## 这个撤离点被倒计时关掉了没（没装倒计时模块 = 不会关）
func _countdown_closed(node: MapNode) -> bool:
	var cd := CountdownModule.of(_run)
	return cd != null and cd.extract_closed(node)



## 局内技能（082）：一个主动技能一颗按钮，能用的亮着；被动的不占按钮。
## 166（作者定）：顶端栏右槽里的图标按钮（`icon_skill_<id>.png`，缺图写技能名），右下角标剩几次；状态写在悬浮窗里
func _refresh_skills() -> void:
	if _skills_box == null or _run == null:
		return
	UiTheme.clear_children(_skills_box)
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
		var hint := d.summary() + ("\n" + Names.description_of(d) if d.description != "" else "") + ("" if d.map_usable() else "\n在战前准备屏（或猎手面前）用")
		var btn := IconButton.make("skill_" + String(d.id), d.display_name,
			d.display_name + ("（" + "，".join(bits) + "）" if not bits.is_empty() else ""), hint, func(): use_skill(d.id))
		btn.badge = _run.skills.uses_of(d.id)
		btn.disabled = _run.skills.can_use(d.id) != "" or not d.map_usable()
		_skills_box.add_child(btn)
	if _run.skills.evading():
		_skills_box.add_child(_label("躲避中（剩 %d 步）" % _run.skills.evade_left, 12, UiPalette.DIM))


## 用一个技能。用不了把原因写在状态栏；用了写进日志
func use_skill(id: StringName) -> bool:
	var why := flow.use_skill(id)
	if why != "":
		say(why)
		return false
	var d := _run.skills.skill(id)
	_note("　用了「%s」：%s" % [d.display_name if d != null else String(id), d.describe() if d != null else ""])
	_refresh_skills()
	_refresh_hud()
	return true


func _route_of_entry(id: int) -> Dictionary:
	var i := _route_index_of_entry(id)
	return _run.map.routes[i] if i >= 0 else {}


func _route_index_of_entry(id: int) -> int:
	for i in _run.map.routes.size():
		if int(_run.map.routes[i].get("entry_id", -1)) == id:
			return i
	return -1


## 作者 2026-10-17：路线卡（风险 / 收益）对玩家隐藏 —— 挑出生点就在地图上点；数还在 [member MapGraph.routes] 里，地图编辑器照看
const SHOW_ROUTES := false
## 右栏：挑出生点阶段每条路线一张卡 —— 这是这一章第一个真正的决策；开局之后收起
func _rebuild_routes() -> void:
	UiTheme.clear_children(_routes_box)
	if not SHOW_ROUTES or _run.phase != RunState.Phase.PICK_SPAWN:
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
	# 166：整屏 = 铺满的地图 + 浮在上面的两行预览与读数层（顶端栏、左下、右下）；地图按读数层占着的边算「刚好放下」
	var area := Control.new()
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)
	_view = MapView.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(_view)
	# 两行预览浮在地图底边正中（左右让开左下图例与右下腰带）
	var lines := _vbox(0)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lines.offset_left = PART_WIDTH + 24
	lines.offset_right = -(PART_WIDTH + 24)
	lines.offset_top = -(PREVIEW_LINES * 22.0 + 8.0)
	lines.offset_bottom = -8
	area.add_child(lines)
	_hud_host = HudHost.new()
	_hud_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_host.arranged.connect(func():
		var inset := _hud_host.content_inset()
		inset.size.y += PREVIEW_LINES * 22.0     # 底下两行预览也别压着路网
		_view.content_inset = inset
		if _drawer != null:
			_drawer.dock(_hud_host.bar_height() + 8.0, DRAWER_MARGIN))
	area.add_child(_hud_host)
	var mid := lines
	_floating = [lines, _hud_host]
	_view.node_pressed.connect(_on_node_pressed)
	_view.node_hovered.connect(_on_node_hovered)
	_view.zoom_changed.connect(_remember_zoom)
	_view.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and _tip != null:
			_tip.follow(get_global_mouse_position()))     # 084：浮窗跟着鼠标走，和道具悬浮窗一样
	# 反馈（bug：悬停节点时地图错位、闪烁）：这两行的文字随悬停的点变长变短，Label 的最小宽度跟着文字走，
	# 把中间这一列撑宽 → 地图视图被挤窄 → 触发 resized 重新居中 → 地图位移、鼠标脱离节点 → 文字清空又缩回去 → 再悬停，如此往复。
	# 让它们不参与布局宽度（超长就省略号裁掉），悬停就不会再改变地图的尺寸
	_preview = _label("", 13, UiPalette.FG)
	_preview.custom_minimum_size.y = 22
	_pin_width(_preview)
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_preview)
	_enemy_line = _label("", 13, UiPalette.DIM)
	_enemy_line.custom_minimum_size.y = 22
	_pin_width(_enemy_line)
	_enemy_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_enemy_line)
	_tip = HoverTip.new()
	add_child(_tip)
	_build_parts()
	_build_drawer()
	flow.screen_changed.connect(func(s: int, _p: Dictionary):
		if s == GameFlow.Screen.MAP:
			_maybe_coach.call_deferred())


## 150 补 1：原来右栏里的东西，一件一个部件（读数层的组件按 id 领走，见 [method hud_part]）
func _build_parts() -> void:
	_shelf = Control.new()
	_shelf.name = "HudShelf"
	_shelf.visible = false
	_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shelf)
	# 150：调试台抽屉（139）—— 箭头是一件部件，抽屉盖在右边；里面是「摆读数」。186：只在开发包里造（[DevGate]）
	if DevGate.on():
		_drawer = DevDrawer.new()
		_part(&"dev_drawer", _drawer.arrow)
	# 作者 2026-10-12：提示行（章节、种子、在哪个点、操作说明，「布局已保存」这类回话）挪进调试台，不再是部件
	_status = _wrapped("", 12, UiPalette.DIM, PART_WIDTH)
	# 090（作者定）：三个互动按键放大到 300%
	# 166（作者定）：背包与「回到这个点」换成顶端栏里的图标按钮（背包 / 放大镜），快捷键照旧
	_bag_btn = IconButton.make("bag", "背包", "背包", "整理棋盘上的东西，打架前先排好", toggle_bag, "B")
	_part(&"bag_button", _bag_btn)
	_reopen_btn = IconButton.make("lens", "放大镜", "放大镜", REOPEN_HINT, func(): reopen(), "N")
	_reopen_btn.disabled = true
	_part(&"reopen_button", _reopen_btn)
	_skills_box = _hbox(4)
	_part(&"skills", _skills_box)
	_routes_box = _vbox(6)
	_part(&"routes", _routes_box, true)
	# 166：日志与「地上 N 件」在调试台里（[method _build_drawer]）
	_log = _log_box(12)
	_log.custom_minimum_size = Vector2(0, LOG_HEIGHT)
	_ground_line = _label("", 13, UiPalette.FG)


func _part(id: StringName, c: Control, full_width: bool = false) -> void:
	if full_width:
		c.custom_minimum_size.x = PART_WIDTH
	_parts[id] = c
	_shelf.add_child(c)


## 读数层的组件来领这一屏的部件（[HudPartWidget]）。没有这个 id 返回 null
func hud_part(id: StringName) -> Control:
	return _parts.get(id, null)


## 组件换掉之前把部件还回来：挂回藏着的架子上（日志照样在记）
func hud_shelve(part: Control) -> void:
	if part != null and is_instance_valid(part) and _shelf != null:
		part.reparent(_shelf, false)


## 150 补 2：调试模式（设置里的开关；没有设置 = 默认）。186：玩家包里永远关着
func debug_mode() -> bool:
	if flow != null and flow.settings != null:
		return flow.settings.debug_on()
	return DevGate.on() and GameSettings.DEBUG_MODE_DEFAULT


## 照设置里的调试模式重摆读数层（变了才重摆）：关掉时日志那件不造，开回来日志里之前写的都还在
func apply_debug_mode() -> void:
	if _hud_host == null or _hud_host.layout == null or _hud_host.debug == debug_mode():
		return
	_hud_host.debug = debug_mode()
	_hud_host.setup(_run, self, _hud_host.layout)
	if _debug_line != null:
		_debug_line.text = _debug_text()


## 150：调试台里的「摆读数」：开着时读数能拖（吸附网格）、右键切显隐、滚轮切大小；保存写回布局文件，重置回默认
func _build_drawer() -> void:
	if _drawer == null:
		return     # 186：玩家包没有调试台（提示行、日志照样记，只是不进树）
	add_child(_drawer)
	# 166（作者定）：侧边悬浮 —— 顶缘在顶端栏下面（不盖右上角的箭头），开着时盖在地图上、不再挤地图（和基地屏一致）
	_drawer.dock(HudHost.BAR_HEIGHT + 8.0, DRAWER_MARGIN)
	var c := _drawer.content
	_debug_line = _label(_debug_text(), 13, UiPalette.STAMINA)     # 150 补 2：头部写着现在的调试模式
	c.add_child(_debug_line)
	c.add_child(_status)     # 作者 2026-10-12：提示行放在调试模式那一行下面
	c.add_child(_ground_line)     # 166：地上几件
	c.add_child(_label("日志", 16, UiPalette.FG))
	c.add_child(_log)     # 166：日志从地图上挪进来
	# 180：玩家看不见种子；调试时在这里指定下一局的（-1 = 开局屏随机取）
	var seed_row := _hbox(8)
	seed_row.add_child(_label("下局种子", 13, UiPalette.DIM))
	_next_seed = SpinBox.new()
	_next_seed.min_value = -1
	_next_seed.max_value = 999999
	_next_seed.value = flow.next_run_seed
	_next_seed.value_changed.connect(func(v: float): flow.next_run_seed = int(v))
	seed_row.add_child(_next_seed)
	c.add_child(seed_row)
	if _run != null and _run.chapter != null and _run.chapter.coach != &"":
		c.add_child(_button("重放教程", func(): show_coach(true), 13))     # 166
	if _run != null and _run.chapter != null and _run.chapter.coach_battle != &"":
		c.add_child(_button("重放战斗教程", replay_battle_coach, 13))     # 166 补充二：下一场再放
	c.add_child(_label("摆读数", 16, UiPalette.FG))
	c.add_child(_wrapped("开着时：拖动读数换位置（松手吸附 %d 像素网格，记成离它最近的锚点 + 偏移）；右键切显示 / 隐藏；滚轮切大小两档。保存写到 %s。" % [
		HudLayout.GRID, HudLayout.save_path("map")], 12, UiPalette.DIM, DevDrawer.WIDTH - 40))
	_hud_edit_btn = _button("摆读数：关", func(): set_hud_editing(not _hud_host.editing), 13)
	c.add_child(_hud_edit_btn)
	c.add_child(_button("保存布局", func(): _say("读数布局已保存" if save_hud_layout() else "读数布局没存上"), 13))
	c.add_child(_button("重置", func():
		reset_hud_layout()
		_say("读数布局回到默认"), 13, UiPalette.Tier.MINOR))
	_drawer.wrap_contents()


func _debug_text() -> String:
	return "调试模式：%s（设置里开关）" % ("开" if debug_mode() else "关")


func hud() -> HudHost:
	return _hud_host


func dev_drawer() -> DevDrawer:
	return _drawer


func set_hud_editing(on: bool) -> void:
	_hud_host.set_editing(on)
	if _hud_edit_btn != null:
		_hud_edit_btn.text = "摆读数：开" if on else "摆读数：关"


func save_hud_layout(path: String = "") -> bool:
	return _hud_host.save(path)


func reset_hud_layout() -> void:
	_hud_host.reset()
	_hud_host.set_editing(_hud_host.editing)


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
			_remember_zoom(0.0)     # 看全图 = 回到自动
		KEY_1:
			_view.zoom = 1.0
			_view.focus(_view.current_id)
			_remember_zoom(1.0)
		_:
			return
	get_viewport().set_input_as_handled()


func _say(text: String) -> void:
	_status.text = text     # 作者 2026-10-12：开发提示行在调试台里


## 186：给玩家的一句 —— 顶端栏下面的提示行（[method HudHost.notice]），调试台的提示行也记一份。组件（腰带）也走它
func say(text: String) -> void:
	_say(text)
	if _hud_host != null:
		_hud_host.notice(text)


## 186：要紧的一句（红、停得久）：倒计时、撤离点关闭、侵蚀、动静
func warn(text: String) -> void:
	_say(text)
	if _hud_host != null:
		_hud_host.notice(text, true)


## 186：提示行（测试看）；布局里删了返回 null
func notice_widget() -> HudWidget:
	return _hud_host.widget(&"notice") if _hud_host != null else null


func _note(text: String) -> void:
	_log.append_text(text + "\n")
#endregion


#region 166：序章静态教程
## 这一章要放的教程步骤（章节的 `coach`，没有 = 不放）
func coach_steps() -> Array:
	if _run == null or _run.chapter == null or _run.chapter.coach == &"":
		return []
	return CoachOverlay.load_steps(_run.chapter.coach)


## 第一次露出地图（开场事件关掉、规则卡收起、地图在最上面）时放一次；放过了记在局外（[member MetaState.coach_seen]）
func _maybe_coach() -> void:
	if _coach != null or _run == null or _run.chapter == null or _run.chapter.coach == &"":
		return
	if flow.screen != GameFlow.Screen.MAP or _rules != null or _pause != null or not is_visible_in_tree():
		return
	if flow.meta != null and flow.meta.coach_seen.has(String(_run.chapter.coach)):
		return
	show_coach()


## 放教程（[param replay]：调试台的「重放」，不管看没看过）。没有步骤返回 false
func show_coach(replay: bool = false) -> bool:
	var steps := coach_steps()
	if steps.is_empty() or _coach != null:
		return false
	if _drawer != null and replay:
		_drawer.set_open(false)
	_coach = CoachOverlay.new()
	_coach.font = font
	_coach.target_rect = func(id: StringName) -> Rect2: return _hud_host.rect_of(id)
	add_child(_coach)
	_coach.finished.connect(func():
		_coach = null
		if flow.meta != null and not flow.meta.coach_seen.has(String(_run.chapter.coach)):
			flow.meta.coach_seen.append(String(_run.chapter.coach))
			flow.save_meta())
	_coach.start(steps)
	return true


func coach() -> CoachOverlay:
	return _coach


## 反馈：进图用玩家上次的缩放（没有就按点距自动），人在正中；作者 2026-10-16：挑出生点时先装下所有出生点、按相对位置偏移视角
func _open_view() -> void:
	var spawns: Array = _run.map.entry_ids.duplicate() if _run.phase == RunState.Phase.PICK_SPAWN else []
	_view.open_at(flow.settings.map_zoom if flow.settings != null else 0.0, spawns)


#region 入局转场（180 §4）
## 能不能走转场：带了预览的几何、换屏淡入开着（跑测试时关着）、是同心环的图
func reveal_allowed(reveal: Dictionary) -> bool:
	if reveal.is_empty() or float(reveal.get("ring_gap", 0.0)) <= 0.0:
		return false
	if not GameDirector.fades_allowed or flow.settings == null or not flow.settings.ui_fades:
		return false
	return _view != null and _view.graph != null and _view.canvas_rect().size.x > 0.0 and MapLayout.for_graph(_view.graph) is RingLayoutBase


## 起点对齐第三页：缩放 = 预览的圈距 ÷ 环距（[constant RingLayoutBase.RING_STEP]），画布中心落在预览圆心 —— 第一帧的圈和预览上的圈重合；
## 终点是平时进图的视角（[method MapView.open_at] 算好的；182：第三页挑好了出生点，人已经站在上面，于是终点就是以出生点为中心）。
## 纸从预览的半径化开到盖过全屏。视图还没尺寸就等它一下
func begin_reveal(reveal: Dictionary) -> void:
	if _view.size.x <= 0.0 or _view.size.y <= 0.0:
		await _view.resized
		if not is_instance_valid(_view):
			return
	var to_local := _view.get_global_transform().affine_inverse()
	var center := to_local * (reveal.get("center", _view.size * 0.5) as Vector2)
	# 182：第三页微放大过时圈的圆心跟着挪了，墨化的那片没动 —— 纸上的洞开在那片上（没给就是圈的圆心）
	var hole := to_local * (reveal.get("mask_center", reveal.get("center", _view.size * 0.5)) as Vector2)
	var zoom0 := float(reveal["ring_gap"]) / RingLayoutBase.RING_STEP
	var far := 0.0
	for corner in [Vector2.ZERO, Vector2(_view.size.x, 0.0), Vector2(0.0, _view.size.y), _view.size]:
		far = maxf(far, hole.distance_to(corner))
	_view.stop_follow()
	_reveal = {"zoom0": zoom0, "pan0": center - _view.canvas_rect().get_center() * zoom0,
		"r0": maxf(0.0, float(reveal.get("radius", 0.0))), "r1": far * 1.3 + MapPreview.SOFTNESS * 2.0, "center": center, "hole": hole}
	_paper = _make_paper(hole)
	var area := _view.get_parent()
	area.add_child(_paper)
	area.move_child(_paper, _view.get_index() + 1)
	apply_reveal(0.0)
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(apply_reveal, 0.0, REVEAL_SEC, REVEAL_SEC)
	_reveal_tween.tween_callback(finish_reveal)


## 那张纸：开局第三页的背景画（有就铺，和那一页同一种铺法），没有就是底色；挂反过来的墨化着色器
func _make_paper(center: Vector2) -> Control:
	var tex := UiTheme.art(UiTheme.ART_SETUP_MAP_BG)
	var paper: Control
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		paper = pic
	else:
		var flat := ColorRect.new()
		flat.color = UiPalette.bg()
		paper = flat
	paper.name = "RevealPaper"
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = MapPreview.SHADER
	m.set_shader_parameter(&"invert", true)
	m.set_shader_parameter(&"softness", MapPreview.SOFTNESS)
	m.set_shader_parameter(&"noise", MapPreview.noise_texture())
	m.set_shader_parameter(&"center", center)
	paper.material = m
	return paper


## 时间线上的第 [param t] 秒（测试直接调）：纸化开、镜头拉近、节点一环一环长出来、装饰浮现、读数最后出来
func apply_reveal(t: float) -> void:
	if _reveal.is_empty():
		return
	var paper := _seg(t, REVEAL_PAPER)
	if _paper != null:
		(_paper.material as ShaderMaterial).set_shader_parameter(&"radius", lerpf(float(_reveal["r0"]), float(_reveal["r1"]), paper * paper))
	var cam := smoothstep(0.0, 1.0, _seg(t, REVEAL_CAMERA))
	var to := reveal_target()
	var z0 := float(_reveal["zoom0"])
	var z1 := float(to["zoom"])
	_view.zoom = z0 * pow(z1 / z0, cam) if z0 > 0.0 and z1 > 0.0 else lerpf(z0, z1, cam)     # 按倍数插值，拉近匀速
	_view.pan = (_reveal["pan0"] as Vector2).lerp(to["pan"], cam)
	_view.node_front = _seg(t, REVEAL_NODES) * float(_view.level_count() + 1)
	_view.deco_alpha = _seg(t, REVEAL_DECO)
	for c in _floating:
		if is_instance_valid(c):
			c.modulate.a = _seg(t, REVEAL_HUD)
	_view.queue_redraw()


## 终点视角：每次现算（读数层摆好、视图换尺寸之后平时进图的视角会变）—— 按平时那样开一次、读回来、再还原
func reveal_target() -> Dictionary:
	var z := _view.zoom
	var p := _view.pan
	_open_view()
	var out := {"zoom": _view.zoom, "pan": _view.pan}
	_view.zoom = z
	_view.pan = p
	return out


## 这一段走了几成
static func _seg(t: float, span: Vector2) -> float:
	return clampf((t - span.x) / maxf(0.001, span.y - span.x), 0.0, 1.0)


## 到头（或被点掉）：撤纸、视角落到终点、节点与装饰画全、读数出来，再放规则卡 / 教程
func finish_reveal() -> void:
	if _reveal.is_empty():
		return
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null
	_open_view()
	_view.node_front = INF
	_view.deco_alpha = 1.0
	for c in _floating:
		if is_instance_valid(c):
			c.modulate.a = 1.0
	_reveal = {}
	if _paper != null:
		_paper.queue_free()
		_paper = null
	_view.queue_redraw()
	_after_open()


func revealing() -> bool:
	return not _reveal.is_empty()


func reveal_paper() -> Control:
	return _paper


## 转场中任意点击 / 按键 = 直接到头
func _input(event: InputEvent) -> void:
	if _reveal.is_empty():
		return
	var press := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo)
	if press:
		finish_reveal()
		get_viewport().set_input_as_handled()
#endregion


## 166 补充二：调试台「重放战斗教程」—— 把看过的那条删掉，下一场战斗再放
func replay_battle_coach() -> void:
	if flow.meta == null or _run == null or _run.chapter == null:
		return
	flow.meta.coach_seen.erase(String(_run.chapter.coach_battle))
	flow.save_meta()
	_say("下一场战斗会再放一次战斗教程")
#endregion
