## 战斗回放（架构文档 4.8）。
##
## [b]整场战斗在开战瞬间就算完了[/b]，这里只是照着 [member BattleResult.log] 重演。
## 因此：
##
## - 快进、倍速、跳过都只是**移动游标**，不会改变任何结果；
## - 表现层不认识 [BattleSim]、[CombatantRuntime] 或棋盘，只认识事件；
## - 玩家在战斗中除了看和跳过没有任何操作 —— 界面上也就只有这两样。
##
## 回放起点取自 [member BattleResult.initial]，而不是自己去编译一遍棋盘：
## 让表现层认识编译器，1.1 的分离就破了。
##
## [b]单位换算集中在这一层。[/b] 日志载荷是定点，而 [method BattleResult.initial]
## 里的快照已经取过整 —— 两边混着往面板送，血条会显示 0 / 0 却画成满格。
## 面板只收取整后的显示值。
class_name BattleView
extends Control

signal finished
## 109：玩家切了倍速（战斗屏接它写回设置，下一场照这个速度开场）
signal speed_changed(speed: float)
## 220：回放里弹了一次反应字（[param side] = 挨反应的那一方）；跳转 / 跳过时不发。战斗屏拿它停下来解释第一次见的反应
signal reaction_shown(id: StringName, side: int)
## 231：一条事件照常播到了画面上（跳转、跳过补的那些不发）—— 战斗屏的双剑铜章跟着它动
signal event_applied(e: BattleEvent)
## 272：玩家按「战记」键收起 / 展开了战记栏（战斗屏接它写回设置）
signal log_toggled(open: bool)

const SPEEDS := GameSettings.BATTLE_SPEEDS
## 167：倍速按钮上的罗马数字（缺图时写它，悬浮窗也写它；不写阿拉伯数字）
const SPEED_NUMERALS := {1: "Ⅰ", 2: "Ⅱ", 4: "Ⅳ"}
## 167：原来底下那行常驻说明，挪进播放键的悬浮窗
const PLAY_HINT := "结果在开打那一瞬就已定，这里只是回放；停在 buff 图标上看效果"
## 221 F1：[constant PLAY_HINT] 按当前语言（中文就是它）
static func play_hint() -> String:
	return UiText.t("battle.play_hint")
## 167（作者定 D 版）：回放控件的符石按键图（`<id>.png` / `_hover` / `_pressed`）。测试指到别处走文字退路
static var art_dir := "res://assets/ui/replay/"
## 166 补充二：战斗教程能指的控件（[method control_rect] 认这些；`next_button` 由战斗屏 [method add_coach_target] 登记）
const COACH_TARGETS: Array[StringName] = [&"timeline", &"play_button", &"speed_button", &"skip_button", &"buffs_mine", &"buffs_enemy", &"next_button"]

var label_font: Font

var _result: BattleResult = null
var _names := [UiText.t("battle.side_mine"), UiText.t("battle.side_enemy")]
var _panels: Array[CombatantPanel] = []
## 103 第 7 条：双方棋盘（只读展示）与盖在上面的冷却遮罩；没给棋盘的一方不画
var _boards: Array[InventoryView] = []
var _overlays: Array[CooldownOverlay] = []
var _board_slots: Array[Control] = []
## 棋盘在回放里的缩放。157 补充一（作者定：去掉文字播报、放大棋盘）：0.5 → 1.0，格子和战前准备一样 60 像素
const BOARD_SCALE := 1.0
## 272（卡上推荐 B）：铜面板里战记栏开着时，棋盘缩到 2/3（格子 40 像素）腾出栏位；收起回 [constant BOARD_SCALE]
const LOG_BOARD_SCALE := 2.0 / 3.0
## 272：铜面板里战记栏的高（六行左右；面板仍放得进 1000 高）
const LOG_HEIGHT := 106.0
var _cursor: int = 0
var _result_was: BattleResult = null
var _now: float = 0.0
var _playing: bool = false
var _speed_idx: int = 0
## 跳转时抑制飘字：一次补上几十条事件会喷一屏数字，那不是信息是噪音
var _suppress_popups: bool = false

## 087：悬浮窗（buff 图标的具体效果）
var _tip: HoverTip = null

var _clock: Label
## 计时 + 胜负那一行（作者 2026-10-17：游戏里的战斗屏不给玩家看，[method set_header_visible]；回放浏览器 / 沙盒照显示）
var _header: HBoxContainer
var _verdict: Label
## 272 战记：逐条的人话记录（[BattleNarrator] 写的行），深底卷栏；[member log_open] 收合
var _ticker: RichTextLabel = null
var _log_box: PanelContainer = null
var _log_btn: IconButton = null
## 战记栏开着没有（进树之前设 = 开场的样子；之后改走 [method set_log_open]）
var log_open: bool = true
## 这一场的战记行（[method BattleNarrator.lines]，名字变了重算）与贴到了第几行
var _lines: Array[Dictionary] = []
var _lines_dirty := true
var _line_next := 0
## 两方法杖轮读的晶石（uid → [晶石 uid…]），战记把法杖写成「法杖·晶石」
var _loads := [{}, {}]
## 铜面板三屏（UI替换美术 bronze3 `battle_arena`，作者 2026-10-21 16:15；进树之前设，战斗屏给）：斗技场图整张铺满（cover、顶对齐，看台在铭牌背后），
## 条与状态小标直接压在图上（[member CombatantPanel.bronze]），两块棋盘套深色外框（[BoardFrame]），时间轴贴着场地下沿
var bronze: bool = false
## 铜面板：内容离场地边
const BRONZE_PAD := 4
## 两块棋盘的外框（自己素皮带、对手生皮）
const BOARD_FRAMES := ["player", "corpse"]
## 整块的竖排（[method add_footer] 往它底下加）
var _root: VBoxContainer = null
var _play_btn: IconButton
var _speed_btn: IconButton
## 157：时间轴（可拖）、收尾战报、双方名牌的位置（面板顶上）
var _timeline: ReplayTimeline
var _report: RichTextLabel
## 铜面板：底栏（空 · 宿主的「继续」· 空）；战报不显示（作者 19:09）
var _footer: HBoxContainer = null
var _report_hidden := false
var _plate_slots: Array[Control] = []
## 157：拖时间轴之前在不在放（松手按原状态接着放）
var _resume_after_scrub := false
var _skip_btn: IconButton
## 166 补充二：教程压着时停住（[method hold]），收掉按原状态接着放（[method release]）
var _held := false
## 231：这一次「看完」是跳过 / 拖到头来的（不是一条条放完的）—— 收尾的动画不演、直接终态
var ended_by_jump := false
var _resume_after_hold := false
## 166 补充二：宿主登记的教程目标（id → 控件）
var _coach_extra: Dictionary = {}


func _ready() -> void:
	if label_font == null:
		label_font = UiPalette.cjk_font()
	_build()
	set_process(true)


#region 播放控制
## 载入一场战斗并从头播。[param names] 只影响标题。
func play(result: BattleResult, names: Array = []) -> void:
	_result = result
	if names.size() == 2:
		_names = [str(names[0]), str(names[1])]
	_cursor = 0
	_now = 0.0
	ended_by_jump = false
	_playing = not _held
	if _held:
		_resume_after_hold = true

	var sides: Array = result.initial.get("sides", [])
	for i in _panels.size():
		_panels[i].display_name = _names[i]
		_panels[i].passives = result.passives[i] if i < result.passives.size() else []
		_panels[i].reset(sides[i] if i < sides.size() else {})
	if not result.buffs.is_empty():
		set_buff_defs(result.buffs)     # 103：上过身的 buff 都在结果里，不用调用方猜
	var cds: Array = result.initial.get("cooldowns", [])
	for i in _overlays.size():
		var secs := {}
		var raw: Dictionary = cds[i] if i < cds.size() else {}
		for uid in raw:
			secs[uid] = StatMath.to_float(int(raw[uid]))
		_overlays[i].reset(secs)
		_overlays[i].now = 0.0
	if _result_was != result:
		_lines_dirty = true
	_result_was = result
	_line_next = 0
	if _ticker != null:
		_ticker.clear()
	_verdict.text = ""
	_timeline.load_result(result)
	_report.text = ""
	_report.visible = false
	_sync_buttons()


## 087：告诉回放双方会出现哪些 buff（id → 定义）：图标用名字、悬浮窗写效果。
## 103：[method play] 已经从 [member BattleResult.buffs] 拿了一份；这里传进来的并进去（老调用方、测试）
func set_buff_defs(defs: Dictionary) -> void:
	for p in _panels:
		var merged: Dictionary = p.buff_defs.duplicate()
		merged.merge(defs, true)
		p.buff_defs = merged
		p.queue_redraw()


## 185 补充一：悬浮窗开着的是哪一格（还剩几秒跟着回放走）、上次写的秒数
var _tip_id := ""
var _tip_side := 0
var _tip_secs := -1


## 停在图标上时开悬浮窗
func _on_buff_hovered(id: String, at: Vector2, side: int = 0) -> void:
	if _tip == null:
		return
	_tip.show_status(buff_tip_parts(id, side), at)
	_tip_id = id
	_tip_side = side
	_tip_secs = -1


## 悬浮窗正文（整段字，测试与老调用方看）
func buff_tip(id: String, side: int = 0) -> String:
	var parts := buff_tip_parts(id, side)
	return String(parts["head"]) + "\n" + String(parts["body"])


## 185（作者 2026-10-17 定稿）：名字行 + 现在的合计（[method Glossary.buff_tip_parts]）；限时的写还剩几秒（作者 16:24）。
## 常驻格、标准轴格、鏖战、格挡套同一版式；机制说明（不可解除、系统层、叠层规则）不给玩家看
func buff_tip_parts(id: String, side: int = 0) -> Dictionary:
	var panel_ := _panels[clampi(side, 0, _panels.size() - 1)]
	if id == CombatantPanel.OVERTIME_CHIP:
		var n := int(panel_.stacks().get(id, 0))
		var sys := _system_of(side, StatAxes.DAMAGE_TAKEN)
		return _parts(Glossary.tip_head(UiText.t("battle.overtime"), Glossary.SYSTEM_NAME_COLOR, "×%d" % n, UiText.t("battle.kind_system")), [StatAxes.effect_text(StatAxes.DAMAGE_TAKEN, sys)])
	if id == CombatantPanel.BLOCK_CHIP:
		return block_tip_parts(panel_)
	if id.begins_with(CombatantPanel.AXIS_PREFIX):
		var a := CombatantPanel.axis_of(id)
		var v := int(panel_.stacks().get(id, 0))
		var kind := UiText.t("battle.kind_debuff") if panel_.is_bad_axis(id) else UiText.t("battle.kind_buff")
		return _parts(Glossary.tip_head(StatAxes.name_of(a, v), "@term", "×%d" % absi(v), kind), [StatAxes.effect_text(a, v + _system_of(side, a))])
	var note := panel_.passive_of(id)
	if note != null:
		return _parts(Glossary.tip_head(note.name, "@term", "", UiText.t("battle.kind_passive")), [note.describe()])
	var def: BuffDef = panel_.buff_defs.get(StringName(id), null)
	if def == null:
		return _parts(Glossary.tip_head(id, "@term"), [UiText.t("battle.missing_paren")])
	return Glossary.buff_tip_parts(def, int(panel_.stacks().get(id, 0)), panel_.time_left(id))


static func _parts(head: String, lines: Array) -> Dictionary:
	var body := Glossary.mark_rich(Glossary.val_numbers("\n".join(lines)), [])
	return {"head": head, "body": "[font_size=%d][color=@tip_fg]%s[/color][/font_size]" % [Glossary.BODY_SIZE, body], "terms": {}}


## 153：「格挡 N」格的悬浮窗 —— 名字行写合计，下面是各层（生效的那层标出来、其余备用）与加固 / 破绽的来源
static func block_tip(p_panel: CombatantPanel) -> String:
	var parts := block_tip_parts(p_panel)
	return String(parts["head"]) + "\n" + String(parts["body"])


static func block_tip_parts(p_panel: CombatantPanel) -> Dictionary:
	var lines: Array[String] = []
	for i in p_panel.block_layers.size():
		var l: Dictionary = p_panel.block_layers[i]
		var who := UiText.t("battle.innate") if String(l["id"]) == "innate" else String(p_panel.item_names.get(int(l["uid"]), l["id"]))
		lines.append("%s %d%s" % [who, int(l["value"]), UiText.t("battle.block_active") if i == 0 else UiText.t("battle.block_spare")])
	if p_panel.axis_value(StatAxes.BLOCK) != 0:
		var a := p_panel.axis_value(StatAxes.BLOCK)
		lines.append("%s ×%d" % [StatAxes.name_of(StatAxes.BLOCK, a), absi(a)])
	for id in p_panel.stacks():
		var def: BuffDef = p_panel.buff_defs.get(StringName(id), null)
		if def != null and def.axis_stacks_per(StatAxes.BLOCK) != 0:
			var n := def.axis_stacks_per(StatAxes.BLOCK) * int(p_panel.stacks()[id])
			lines.append(UiText.t("battle.block_source") % [StatAxes.name_of(StatAxes.BLOCK, n), absi(n), Names.of(def)])
	return _parts(Glossary.tip_head(UiText.t("battle.block"), "@term", str(p_panel.block_value())), lines)


## 回放到当前游标为止，某一方某条轴的系统层（从日志里最近一条 axis_shifted 读）
func _system_of(side: int, axis: StringName) -> int:
	if _result == null:
		return 0
	var out := 0
	for i in mini(_cursor, _result.log.size()):
		var e := _result.log[i] as BattleEvent
		if e.name == BattleEvent.AXIS_SHIFTED and e.side == side and e.get_name(&"axis") == axis:
			out = e.get_int(&"system_stacks")
	return out


func _on_buff_unhovered() -> void:
	if _tip != null:
		_tip.release()


## 103 第 7 条：把一方的棋盘交给回放（只读展示）。uid 和日志里的一致（就是编译它的那张，[member CombatantSpec.board]）。
## 冷却遮罩盖在上面，跟着回放时刻（含倍速）转
func set_board(side: int, board: GridInventory) -> void:
	if side < 0 or side >= _board_slots.size() or board == null:
		return
	var view := _boards[side]
	view.inventory = board
	_board_slots[side].custom_minimum_size = view.custom_minimum_size * board_scale()
	view.scale = Vector2.ONE * board_scale()
	_board_slots[side].visible = true
	if _board_slots[side].get_parent() is BoardFrame:
		(_board_slots[side].get_parent() as Control).visible = true


## 272 战记栏的字
func ticker() -> RichTextLabel:
	return _ticker


## 272：战记栏（深底卷栏）
func log_box() -> PanelContainer:
	return _log_box


func log_button() -> IconButton:
	return _log_btn


## 272：这一场的战记行（名字表变了才重算）
func log_lines() -> Array[Dictionary]:
	if _lines_dirty and _result != null:
		var item_names: Array = []
		for p in _panels:
			item_names.append(p.item_names)
		_lines = BattleNarrator.lines(_result, _names, item_names, _loads)
		_lines_dirty = false
	return _lines


## 战记栏里现在贴了几行
func log_shown() -> int:
	return _line_next


## 272：收起 / 展开战记栏（铜面板里棋盘跟着缩放）；[param user] 真 = 玩家按的键（发 [signal log_toggled]）
func set_log_open(v: bool, user: bool = false) -> void:
	log_open = v
	if _log_box != null:
		_log_box.visible = v
	_apply_board_scale()
	if _log_btn != null:
		_log_btn.set_art(_log_art(), UiText.t("battle.log"), UiText.t("battle.log_tip"))
	if user:
		log_toggled.emit(v)


## 测试反馈（v5.00）：栏高不是行高的整数倍时，滚到底后最上面那行只露半截（中号、大号字）。
## 战记的高按整行取：栏里放得下几整行就给几行高，竖直居中
func _fit_ticker_rows() -> void:
	if _ticker == null or _log_box == null:
		return
	var rows := ticker_rows()
	if rows <= 0:
		return
	_ticker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ticker.custom_minimum_size.y = rows * _ticker_line_height() + _ticker_pad()


## 战记栏放得下几整行
func ticker_rows() -> int:
	var lh := _ticker_line_height()
	if lh <= 0.0 or _log_box == null:
		return 0
	var box_pad := _log_box.get_theme_stylebox("panel").get_minimum_size().y if _log_box.has_theme_stylebox("panel") else 0.0
	return maxi(1, floori((_log_box.size.y - box_pad - _ticker_pad()) / lh))


func _ticker_line_height() -> float:
	var font := _ticker.get_theme_font("normal_font")
	if font == null:
		return 0.0
	return font.get_height(_ticker.get_theme_font_size("normal_font_size")) + _ticker.get_theme_constant("line_separation")


func _ticker_pad() -> float:
	return _ticker.get_theme_stylebox("normal").get_minimum_size().y if _ticker.has_theme_stylebox("normal") else 0.0


## 战记键的图：栏开着 log_open，收起 log_closed
func _log_art() -> String:
	return "log_open" if log_open else "log_closed"


func toggle_log() -> void:
	set_log_open(not log_open, true)


## 棋盘现在的缩放（铜面板里战记开着就缩）
func board_scale() -> float:
	return LOG_BOARD_SCALE if bronze and log_open else BOARD_SCALE


func _apply_board_scale() -> void:
	var k := board_scale()
	for i in _boards.size():
		_boards[i].scale = Vector2.ONE * k
		if _boards[i].inventory != null:
			_board_slots[i].custom_minimum_size = _boards[i].custom_minimum_size * k


func board_view(side: int) -> InventoryView:
	return _boards[side] if side >= 0 and side < _boards.size() else null


func overlay(side: int) -> CooldownOverlay:
	return _overlays[side] if side >= 0 and side < _overlays.size() else null


## 告诉回放某一方的 uid 叫什么名字。日志里只有 uid —— 名字纯属表现层的事，
## 塞进日志只会让每条事件都背着一串用不上的字符串。
func set_item_names(side: int, names: Dictionary) -> void:
	if side >= 0 and side < _panels.size():
		_panels[side].item_names = names
		_lines_dirty = true


## 272：一方法杖轮读的晶石（法杖 uid → [晶石 uid…]，[method CombatantSpec.loads_of]）
func set_loads(side: int, loads: Dictionary) -> void:
	if side >= 0 and side < _loads.size():
		_loads[side] = loads
		_lines_dirty = true


## 157：一方的名牌放在它的面板顶上（战斗屏给；沙盒、回放浏览器不给就没有）
func set_nameplate(side: int, plate: Control) -> void:
	if side < 0 or side >= _plate_slots.size() or plate == null:
		return
	UiTheme.clear_children(_plate_slots[side])
	_plate_slots[side].add_child(plate)
	_plate_slots[side].visible = true
	if side < _panels.size():
		_panels[side].show_title = false     # 作者 2026-10-13：名牌上有名字了，面板顶上那行不再重复


func timeline() -> ReplayTimeline:
	return _timeline


## 157：收尾战报那一行（没播完是空的）
func report() -> String:
	return _report.text if _report != null else ""


## 回放现在的时刻（秒）
func now() -> float:
	return _now


func panel(side: int) -> CombatantPanel:
	return _panels[side] if side >= 0 and side < _panels.size() else null


## 跳过：把游标推到末尾。**结果一模一样** —— 这是事件驱动带来的，不是特例。
## 157：一次补上整场，三种反馈和飘字一起抑制
func skip_to_end() -> void:
	if _result == null:
		return
	_now = _result.duration_sec() + 0.001
	ended_by_jump = true
	_suppress_popups = true
	_drain_until(_now)
	_suppress_popups = false
	_finish()


## 跳到某一时刻并暂停。
##
## 回放是照日志重演，没有任何内部状态需要倒推，所以「跳转」就是
## 从头再快放一遍到那一刻 —— 便宜且不可能和正常播放不一致。
func seek(t: float) -> void:
	if _result == null:
		return
	play(_result, _names)
	_playing = false
	_suppress_popups = true
	_now = maxf(0.0, t)
	_drain_until(_now)
	_sync_overlays()
	_suppress_popups = false
	_clock.text = UiText.t("battle.clock") % _now
	_timeline.cursor = _now
	_sync_buttons()
	if _cursor >= _result.log.size():
		ended_by_jump = true
		_finish()     # 157：拖到了头 = 看完了（战报照出）


## 157：时间轴开拖：记下在不在放，拖着时停着
func _on_scrub_started() -> void:
	_resume_after_scrub = _playing


func _on_scrub_ended() -> void:
	if _resume_after_scrub and _result != null and _cursor < _result.log.size():
		_playing = true
		_sync_buttons()
	_resume_after_scrub = false


## 166 补充二：教程开着 —— 停住（和拖时间轴一样：记下在不在放，[method _process] 不推时间）
func hold() -> void:
	if _held:
		return
	_held = true
	_resume_after_hold = _playing
	_playing = false
	_sync_buttons()


## 教程收掉：按停之前的样子接着放（播完了就不动）
func release() -> void:
	if not _held:
		return
	_held = false
	if _resume_after_hold and _result != null and _cursor < _result.log.size():
		_playing = true
	_resume_after_hold = false
	_sync_buttons()


func is_held() -> bool:
	return _held


func is_playing() -> bool:
	return _playing


## 宿主（战斗屏）登记一个教程目标（「跳过并继续」在回放层外面）
func add_coach_target(id: StringName, c: Control) -> void:
	_coach_extra[id] = c


## 166 补充二：教程目标的全局包围盒（[constant COACH_TARGETS]）；没有 / 不在屏上 = 空矩形
func control_rect(id: StringName) -> Rect2:
	var c: Control = null
	match id:
		&"timeline": c = _timeline
		&"play_button": c = _play_btn
		&"speed_button": c = _speed_btn
		&"skip_button": c = _skip_btn
		&"buffs_mine", &"buffs_enemy":     # 220：对手那一排（反应解释指它）
			var p := panel(0 if id == &"buffs_mine" else 1)
			if p == null or not p.is_visible_in_tree():
				return Rect2()
			var r := p.chips_rect()
			return Rect2(p.get_global_transform() * r.position, r.size * p.get_global_transform().get_scale())
		_: c = _coach_extra.get(id, null)
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return Rect2()
	return c.get_global_rect()


func toggle_play() -> void:
	if _result == null:
		return
	if _cursor >= _result.log.size():
		play(_result, _names)  # 播完了再按就是重播
		return
	_playing = not _playing
	_sync_buttons()


func cycle_speed() -> void:
	_speed_idx = (_speed_idx + 1) % SPEEDS.size()
	_sync_buttons()
	speed_changed.emit(speed())


## 109：开场倍速（从设置来）；不在 [constant SPEEDS] 里的按 1×。不发 [signal speed_changed] —— 这不是玩家切的
func set_speed(v: float) -> void:
	_speed_idx = maxi(0, SPEEDS.find(GameSettings.normalize_speed(v)))
	if _speed_btn != null:
		_sync_buttons()


func speed() -> float:
	return SPEEDS[_speed_idx]
#endregion


func _process(delta: float) -> void:
	if not _playing or _result == null:
		return
	_now += delta * SPEEDS[_speed_idx]
	_drain_until(_now)
	_sync_overlays()
	_clock.text = UiText.t("battle.clock") % _now
	_timeline.cursor = _now
	if _cursor >= _result.log.size():
		_finish()


func _drain_until(t: float) -> void:
	var log_ := _result.log
	while _cursor < log_.size():
		var e := log_[_cursor] as BattleEvent
		if StatMath.to_float(e.time) > t:
			break
		_apply(e)
		_cursor += 1
		if _held and not _suppress_popups:
			break     # 220：这一条把回放停住了（反应解释）—— 后面的等放开再走，不在停着时偷跑
	_flush_log(_cursor - 1)


## 272：把引出事件已经放过（下标 ≤ [param upto]）的战记行贴上去
func _flush_log(upto: int) -> void:
	if _ticker == null or _result == null:
		return
	var all := log_lines()
	var tone := UiTheme.tone_at(_ticker)
	var added := false
	while _line_next < all.size() and int(all[_line_next]["at"]) <= upto:
		_ticker.append_text(UiTheme.ink_bbcode(String(all[_line_next]["text"]), tone) + "\n")
		_line_next += 1
		added = true
	while added and _ticker.get_paragraph_count() > BattleNarrator.MAX_LINES + 1:
		_ticker.remove_paragraph(0)


## 遮罩的进度是回放时刻的纯函数：倍速、跳转都只是 _now 变了
func _sync_overlays() -> void:
	for o in _overlays:
		o.now = _now
	for p in _panels:
		p.set_now(_now)     # 185：图标上的计时环
	_refresh_tip_time()


## 185 补充一：开着的状态窗里「还剩 N 秒」跟着回放时刻走（秒数变了才换字；暂停时不走）
func _refresh_tip_time() -> void:
	if _tip == null or _tip_id == "" or not _tip.is_showing():
		return
	var panel_ := _panels[clampi(_tip_side, 0, _panels.size() - 1)]
	var left := panel_.time_left(_tip_id)
	if left < 0.0 or ceili(left) == _tip_secs:
		return
	_tip_secs = ceili(left)
	_tip.update_status(buff_tip_parts(_tip_id, _tip_side))


func _finish() -> void:
	if not _playing and _verdict.text != "":
		return
	_playing = false
	_clock.text = UiText.t("battle.clock") % _result.duration_sec()
	_verdict.text = (
		UiText.t("battle.draw") if _result.is_draw() else UiText.t("battle.wins") % _names[_result.winner]
	)
	_timeline.cursor = _result.duration_sec()
	_report.text = report_of(_result, _names)     # 157：收尾战报（跳过也出）
	_flush_log(_result.log.size())     # 272：战记末行 = 战报
	_report.visible = not _report_hidden
	_sync_buttons()
	if result_cue(_result) != &"":
		_sfx(result_cue(_result))
	finished.emit()


## 157：收尾战报：几秒、双方各造成多少、谁打倒了谁（272 起是战记的末行，[method BattleNarrator.report]）
static func report_of(result: BattleResult, names: Array) -> String:
	return BattleNarrator.report(result, names)


## 157：倍速 ≥ 4 时三种反馈按倍速缩短（不叠加，新的一下打断上一下）
func _feedback_scale() -> float:
	var sp := speed()
	return 1.0 / sp if sp >= 4.0 else 1.0


#region 事件 → 画面
func _apply(e: BattleEvent) -> void:
	match e.name:
		BattleEvent.BATTLE_START:
			_sfx(&"battle.start")     # 206 补一：开场号角
		BattleEvent.RESOURCE_CHANGED:
			if e.side >= 0 and e.side < _panels.size():
				var key := String(e.get_name(&"key"))
				if key == CombatantPanel.ARMOR_KEY and _panels[e.side].armor_value() > 0 and e.get_int(&"current") <= 0:
					_sfx(&"battle.armor_break")     # 206：护甲打穿
				_panels[e.side].set_resource(
					key,
					StatMath.to_int(e.get_int(&"current")),
					StatMath.to_int(e.get_int(&"max"))
				)
		BattleEvent.DAMAGE:
			_on_damage(e)
		BattleEvent.STATUS_STACKED, BattleEvent.STATUS_UNSTACKED:
			if e.side >= 0 and e.side < _panels.size():
				var buff := String(e.get_name(&"buff"))
				var first := e.name == BattleEvent.STATUS_STACKED and e.get_int(&"stacks") > 0 and not _panels[e.side].stacks().has(buff)
				_panels[e.side].set_stacks(buff, e.get_int(&"stacks"))
				if e.name == BattleEvent.STATUS_STACKED:
					_panels[e.side].note_stacked(buff, e.payload, StatMath.to_float(e.time))     # 185 补充一：限时状态的计时
				if e.payload.has("guard"):
					_panels[e.side].guards[buff] = e.get_int(&"guard")     # 175 补充四：凝毒 / 冻疮的保底
				if first and not _suppress_popups:
					_panels[e.side].pop(buff, _feedback_scale())     # 157：buff 上身（首层）
					var def: BuffDef = _panels[e.side].buff_defs.get(StringName(buff), null)
					_sfx(&"battle.buff_down" if def != null and def.is_debuff else &"battle.buff_up")
		BattleEvent.AXIS_SHIFTED:
			if e.side >= 0 and e.side < _panels.size():
				_panels[e.side].set_axis(String(e.get_name(&"axis")), e.get_int(&"stacks"))
		BattleEvent.OVERTIME_STACKED:
			for p in _panels:
				p.set_overtime(e.get_int(&"count"))
		BattleEvent.ITEM_FIRED, BattleEvent.ITEM_SKIPPED:
			if e.side >= 0 and e.side < _panels.size():
				if e.name == BattleEvent.ITEM_FIRED:
					_panels[e.side].note_fired(e.get_int(&"uid"), _now)
					_flash(e)
				if e.payload.has("ready_at") and e.side < _overlays.size():
					_overlays[e.side].note_cycle(e.get_int(&"uid"), StatMath.to_float(e.time), StatMath.to_float(e.get_int(&"ready_at")))
				if e.payload.has("steps") and e.side < _overlays.size():
					_overlays[e.side].note_step(e.get_int(&"uid"), e.get_int(&"next"), e.get_int(&"steps"))     # 175：法杖轮读到第几颗
		BattleEvent.EFFECT_RESOLVED:
			if e.get_int(&"uid") > 0:
				_flash(e)     # 157：规则触发也算那一件出手
			if String(e.payload.get("effect", "")) == ReactionResolver.EFFECT:
				_on_reaction(e)
		BattleEvent.DIED:
			if e.side >= 0 and e.side < _panels.size():
				_panels[e.side].mark_dead()
				_sfx(&"battle.fall")
	if not _suppress_popups:
		event_applied.emit(e)


## 157：出手那件的格子亮一下（跳转时不亮）
func _flash(e: BattleEvent) -> void:
	if _suppress_popups or e.side < 0 or e.side >= _overlays.size():
		return
	_overlays[e.side].flash(e.get_int(&"uid"), StatMath.to_float(e.time))


func _on_damage(e: BattleEvent) -> void:
	var amount := e.get_int(&"amount")
	if _suppress_popups or e.side < 0 or e.side >= _panels.size():
		return
	if e.get_int(&"block") > 0:
		_sfx(&"battle.block")     # 206：格挡减了伤（负数是破绽，不算）
	if amount == 0:
		return
	if amount > 0:
		_panels[e.side].shake(_feedback_scale())     # 157：挨打的一方整块抖一下
		_sfx(StringName("battle.hit." + String(e.get_name(&"type"))))
		if e.get_bool(&"crit"):
			_sfx(&"battle.crit")     # 叠在命中上
	# amount 为负表示这一下最终是治疗（受伤前效果把它反转了）
	_panels[e.side].popup(
		StatMath.to_int(absi(amount)), e.get_name(&"type"), amount < 0, e.get_bool(&"crit")
	)


## 175：反应弹字（挨打的那一方面板上），跳转时不弹
func _on_reaction(e: BattleEvent) -> void:
	if _suppress_popups or e.side < 0 or e.side >= _panels.size():
		return
	_panels[e.side].popup_text(reaction_label(e), reaction_color(e), _feedback_scale())
	_sfx(StringName("battle.reaction." + String(e.get_name(&"reaction"))))
	reaction_shown.emit(e.get_name(&"reaction"), e.side)


## 206：战斗音效都走这里。跳转（不弹字）时全不响；倍速 ≥ 4 只放行开场、暴击、反应、倒下、胜负
func _sfx(cue: StringName) -> void:
	if _suppress_popups:
		return
	if speed() >= 4.0 and not fast_cue(cue):
		return
	AudioHub.play(cue)


## 206：收尾那一声：玩家一方（0）赢 win、输 lose；平局不响（空）
static func result_cue(result: BattleResult) -> StringName:
	if result == null or result.is_draw():
		return &""
	return &"battle.win" if result.winner == 0 else &"battle.lose"


## 206：倍速 ≥ 4 时还放行的那几个
static func fast_cue(cue: StringName) -> bool:
	var s := String(cue)
	return s in ["battle.start", "battle.crit", "battle.fall", "battle.win", "battle.lose"] or s.begins_with("battle.reaction.")


## 175：反应名（当前语言；反应表里查不到就写 id）
static func reaction_label(e: BattleEvent) -> String:
	var def := ReactionResolver.by_id(e.get_name(&"reaction"))
	return Names.of(def) if def != null else String(e.get_name(&"reaction"))


## 175：弹字颜色 = 第一种元素的伤害色
static func reaction_color(e: BattleEvent) -> Color:
	var els: Array = e.payload.get("elements", [])
	return UiPalette.damage_color(StringName(String(els[0]))) if not els.is_empty() else UiPalette.CRIT


#endregion


#region 界面
func _build() -> void:
	var bg := UiTheme.prepare_root(self, false)     # 091：底色跟设置走 —— 设置由宿主（导演 / 沙盒 / 回放浏览器）读过、apply 过，这里不再读盘
	# 战斗背景（白天的沙地场子，铺满裁边）垫在最底层；直接写在它上面的字（顶上一行、战报、播报）按它的深浅取字色，
	# 对阵面板、名牌自带深底，不跟着变
	var pic := UiTheme.dress_backdrop(bg, UiTheme.ART_BATTLE_BG, "BattleBackdrop")
	if bronze and pic != null:
		_cover_top(pic)
	var on_bg := UiTheme.art_tone(UiTheme.ART_BATTLE_BG)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if bronze:     # 高按内容：场地图跟着内容（名牌、条、棋盘、时间轴）一起长
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, BRONZE_PAD)
		root.minimum_size_changed.connect(update_minimum_size)
	root.add_theme_constant_override("separation", 8 if bronze else 12)
	add_child(root)
	_root = root

	var header := HBoxContainer.new()
	_header = header
	header.add_theme_constant_override("separation", 12)
	UiTheme.set_tone(header, on_bg)
	root.add_child(header)
	_clock = UiTheme.make_label(UiText.t("battle.clock") % 0.0, 16, UiPalette.DIM)
	header.add_child(_clock)
	_verdict = UiTheme.make_label("", 16, UiPalette.FG)
	header.add_child(_verdict)

	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 16)
	root.add_child(arena)
	for i in 2:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6 if bronze else 8)
		arena.add_child(col)
		var plate_slot := MarginContainer.new()     # 157：名牌（战斗屏给了才有）
		plate_slot.visible = false
		col.add_child(plate_slot)
		_plate_slots.append(plate_slot)
		var p := CombatantPanel.new()
		p.bronze = bronze
		p.label_font = label_font
		p.display_name = _names[i]
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.buff_hovered.connect(_on_buff_hovered.bind(i))
		p.buff_unhovered.connect(_on_buff_unhovered)
		col.add_child(p)
		_panels.append(p)
		# 103 第 7 条：棋盘（缩小）+ 冷却遮罩。没给棋盘就藏着
		var slot := Control.new()
		slot.visible = false
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(slot)
		var board := InventoryView.new()
		board.label_font = label_font
		board.scale = Vector2.ONE * BOARD_SCALE
		slot.add_child(board)
		if bronze:
			BoardFrame.around(slot, String(BOARD_FRAMES[i])).visible = false     # 框跟着棋盘：给了才显示
			board.seams = BoardFrame.dark_seams()
		var o := CooldownOverlay.new()
		o.view = board
		board.add_child(o)
		_board_slots.append(slot)
		_boards.append(board)
		_overlays.append(o)

	# 272 战记：棋盘下方、控制条上方一栏深底卷栏（铜面板定高 [constant LOG_HEIGHT]；开发工具里撑满剩下的高）
	_log_box = PanelContainer.new()
	_log_box.theme_type_variation = UiTheme.PANEL_TOOLTIP     # 实底深色（和悬浮窗同一块底）：压在沙地上也读得清
	UiTheme.apply_tone(_log_box, UiTheme.PANEL_TOOLTIP)
	if bronze:
		_log_box.custom_minimum_size = Vector2(0, LOG_HEIGHT)
	else:
		_log_box.custom_minimum_size = Vector2(0, 90)
		_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_log_box)
	_ticker = RichTextLabel.new()
	_ticker.bbcode_enabled = true
	_ticker.scroll_following = true
	_ticker.selection_enabled = false
	_ticker.theme_type_variation = UiTheme.RICH_SMALL     # 121：13 号
	_ticker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.set_tone(_ticker, UiTheme.TONE_DARK)
	_log_box.add_child(_ticker)
	_log_box.resized.connect(_fit_ticker_rows)
	if bronze:
		var spacer := Control.new()     # 157 补充一：剩下的高让给棋盘，控制条压在底下
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(spacer)
		root.move_child(spacer, _log_box.get_index())

	# 157：播放键 · 时间轴（可拖）· 倍速与跳过在杆的右端；播完了在下面出战报。
	# 167：三个键是符石图（[method IconButton.make_art]），缺图写字；原来那行说明挪进播放键的悬浮窗
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	_play_btn = IconButton.make_art(art_dir, "", "", "", toggle_play)     # 图与悬浮窗由 _sync_buttons 按状态给
	bar.add_child(_play_btn)
	_timeline = ReplayTimeline.new()
	_timeline.seek_requested.connect(seek)
	_timeline.scrub_started.connect(_on_scrub_started)
	_timeline.scrub_ended.connect(_on_scrub_ended)
	bar.add_child(_timeline)
	_speed_btn = IconButton.make_art(art_dir, "", "", "", cycle_speed)
	bar.add_child(_speed_btn)
	_skip_btn = IconButton.make_art(art_dir, "skip", UiText.t("battle.skip"), UiText.t("battle.skip_tip"), skip_to_end)
	bar.add_child(_skip_btn)
	_log_btn = IconButton.make_art(art_dir, _log_art(), UiText.t("battle.log"), UiText.t("battle.log_tip"), toggle_log)     # 272：卷轴定稿（作者 11-04 选 A），开着是摊开的手卷、收起是扎好的一卷
	bar.add_child(_log_btn)
	set_log_open(log_open)
	_report = UiTheme.rich_block(0, UiTheme.RICH_SMALL_SIZE)
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_report.visible = false
	if bronze:
		_build_footer()
	else:
		UiTheme.set_tone(_report, on_bg)
		_report.set_meta(&"exempt_bare_text", "dev")     # 226 守门：非铜面板的战报只在开发工具（回放浏览器、沙盒）里出
		root.add_child(_report)
	_tip = HoverTip.new()
	add_child(_tip)
	_sync_buttons()


func _get_minimum_size() -> Vector2:
	return _root.get_combined_minimum_size() + Vector2.ONE * BRONZE_PAD * 2 if bronze and _root != null else Vector2.ZERO


## 战报显不显示（铜面板不显示，测试看）
func report_shown() -> bool:
	return _report.visible


## 231：名牌、条、棋盘、时间轴那一整块（开战过场先藏着、沙场显出后再淡进来）
func content() -> Control:
	return _root


## 宿主的控件挂在回放最底下（时间轴、战报之下），压在斗技场图上（铜面板：「继续」那一格，场地图一直铺到底，夹在底栏正中）。进树之后调
func add_footer(c: Control) -> void:
	if _footer != null:
		_footer.add_child(c)
		_footer.move_child(c, 1)
	else:
		_root.add_child(c)


## 铜面板的底栏：正中留给宿主的「继续」，左右两半空着让它居中。作者 19:09：左下的战报不画（战报的字照样算，测试与调试看 [method report]）
func _build_footer() -> void:
	_footer = UiTheme.hbox(12)
	_root.add_child(_footer)
	for i in 2:
		var half := Control.new()
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_footer.add_child(half)
	_report_hidden = true
	add_child(_report)     # 不进排版，一直藏着


## 铜面板：底图 cover、顶对齐（[method UiTheme.dress_backdrop] 是居中裁）—— 宿主变大小时重算
func _cover_top(pic: TextureRect) -> void:
	var host := pic.get_parent() as Control
	host.clip_contents = true
	pic.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	var fit := func():
		var ts := pic.texture.get_size()
		var k := maxf(host.size.x / ts.x, host.size.y / ts.y)
		pic.size = ts * k
		pic.position = Vector2((host.size.x - pic.size.x) * 0.5, 0.0)
	host.resized.connect(fit)
	fit.call()


func _sync_buttons() -> void:
	if _play_btn == null:
		return
	var done := _result != null and _cursor >= _result.log.size()
	var id := "replay" if done else ("pause" if _playing else "play")
	var name_: String = UiText.t("battle." + id)     # battle.replay / battle.pause / battle.play
	if _play_btn.icon_id != id:
		_play_btn.set_art(id, name_, name_ + "\n" + play_hint())
	var x := int(SPEEDS[_speed_idx])
	if _speed_btn.icon_id != "speed_%d" % x:
		_speed_btn.set_art("speed_%d" % x, SPEED_NUMERALS[x], UiText.t("battle.speed_tip") % SPEED_NUMERALS[x])
#endregion


## 作者 2026-10-17：计时与「X 获胜」那一行藏不藏（游戏里的战斗屏藏，调试用的回放浏览器留着）
func set_header_visible(v: bool) -> void:
	if _header != null:
		_header.visible = v


func header_visible() -> bool:
	return _header != null and _header.visible
