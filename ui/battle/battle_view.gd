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

const SPEEDS := [1.0, 2.0, 4.0]

var label_font: Font

var _result: BattleResult = null
var _names := ["我方", "敌方"]
var _panels: Array[CombatantPanel] = []
var _cursor: int = 0
var _now: float = 0.0
var _playing: bool = false
var _speed_idx: int = 0
## 跳转时抑制飘字：一次补上几十条事件会喷一屏数字，那不是信息是噪音
var _suppress_popups: bool = false

## 087：悬浮窗（buff 图标的具体效果）
var _tip: HoverTip = null

var _clock: Label
var _verdict: Label
var _ticker: RichTextLabel
var _play_btn: Button
var _speed_btn: Button


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
	_playing = true

	var sides: Array = result.initial.get("sides", [])
	for i in _panels.size():
		_panels[i].display_name = _names[i]
		_panels[i].reset(sides[i] if i < sides.size() else {})
	_ticker.clear()
	_verdict.text = ""
	_sync_buttons()


## 087：告诉回放双方会出现哪些 buff（id → 定义）：图标用名字、悬浮窗写效果。从双方的战斗单位收集（[Glossary.buffs_in_spec]）
func set_buff_defs(defs: Dictionary) -> void:
	for p in _panels:
		p.buff_defs = defs
		p.queue_redraw()


## 停在图标上时开悬浮窗
func _on_buff_hovered(id: String, at: Vector2) -> void:
	if _tip == null:
		return
	var def: BuffDef = _panels[0].buff_defs.get(StringName(id), null)
	var name := Names.of(def) if def != null and Names.of(def) != "" else id
	var body := Glossary.describe_buff(def) if def != null else "（没有这个 buff 的定义）"
	_tip.show_text("[b]%s[/b]\n%s" % [name, body], at)


func _on_buff_unhovered() -> void:
	if _tip != null:
		_tip.hide_tip()


## 告诉回放某一方的 uid 叫什么名字。日志里只有 uid —— 名字纯属表现层的事，
## 塞进日志只会让每条事件都背着一串用不上的字符串。
func set_item_names(side: int, names: Dictionary) -> void:
	if side >= 0 and side < _panels.size():
		_panels[side].item_names = names


## 跳过：把游标推到末尾。**结果一模一样** —— 这是事件驱动带来的，不是特例。
func skip_to_end() -> void:
	if _result == null:
		return
	_now = _result.duration_sec() + 0.001
	_drain_until(_now)
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
	_suppress_popups = false
	_clock.text = "%.2f 秒" % _now
	_sync_buttons()


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
#endregion


func _process(delta: float) -> void:
	if not _playing or _result == null:
		return
	_now += delta * SPEEDS[_speed_idx]
	_drain_until(_now)
	_clock.text = "%.2f 秒" % _now
	if _cursor >= _result.log.size():
		_finish()


func _drain_until(t: float) -> void:
	var log := _result.log
	while _cursor < log.size():
		var e := log[_cursor] as BattleEvent
		if StatMath.to_float(e.time) > t:
			break
		_apply(e)
		_cursor += 1


func _finish() -> void:
	if not _playing and _verdict.text != "":
		return
	_playing = false
	_clock.text = "%.2f 秒" % _result.duration_sec()
	_verdict.text = (
		"平局" if _result.is_draw() else "%s 获胜" % _names[_result.winner]
	)
	_sync_buttons()
	finished.emit()


#region 事件 → 画面
func _apply(e: BattleEvent) -> void:
	match e.name:
		BattleEvent.RESOURCE_CHANGED:
			if e.side >= 0 and e.side < _panels.size():
				_panels[e.side].set_resource(
					String(e.get_name(&"key")),
					StatMath.to_int(e.get_int(&"current")),
					StatMath.to_int(e.get_int(&"max"))
				)
		BattleEvent.DAMAGE:
			_on_damage(e)
		BattleEvent.STATUS_STACKED, BattleEvent.STATUS_UNSTACKED:
			if e.side >= 0 and e.side < _panels.size():
				_panels[e.side].set_stacks(
					String(e.get_name(&"buff")), e.get_int(&"stacks")
				)
		BattleEvent.ITEM_FIRED:
			if e.side >= 0 and e.side < _panels.size():
				_panels[e.side].note_fired(e.get_int(&"uid"), _now)
		BattleEvent.DIED:
			if e.side >= 0 and e.side < _panels.size():
				_panels[e.side].mark_dead()
		BattleEvent.DISPATCH_OVERFLOW:
			_log_line(e.time, "[color=#e0a030]派发超限，内容可能配出了死循环[/color]")
	_log_event(e)


func _on_damage(e: BattleEvent) -> void:
	var amount := e.get_int(&"amount")
	if amount == 0 or _suppress_popups or e.side < 0 or e.side >= _panels.size():
		return
	# amount 为负表示这一下最终是治疗（受伤前效果把它反转了）
	_panels[e.side].popup(
		StatMath.to_int(absi(amount)), e.get_name(&"type"), amount < 0
	)


## 事件条。回放时最有用的其实不是血条，而是「刚才到底发生了什么」——
## 内容配错时这一栏比血条先告诉你。
func _log_event(e: BattleEvent) -> void:
	match e.name:
		BattleEvent.DAMAGE:
			var amt := StatMath.to_int(absi(e.get_int(&"amount")))
			if amt == 0 and e.get_int(&"absorbed") == 0:
				return
			var bits: Array[String] = []
			if e.get_int(&"absorbed") > 0:
				bits.append("盾挡 %d" % StatMath.to_int(e.get_int(&"absorbed")))
			if e.get_int(&"armor") > 0:
				bits.append("甲挡 %d" % StatMath.to_int(e.get_int(&"armor")))
			var tail := ("（%s）" % "、".join(bits)) if not bits.is_empty() else ""
			var color := UiPalette.damage_color(e.get_name(&"type")).to_html(false)
			_log_line(e.time, "[color=#%s]%s %s %d%s[/color]" % [
				color, _side_name(e.side),
				"回复" if e.get_int(&"amount") < 0 else "受到",
				amt, tail,
			])
		BattleEvent.STATUS_STACKED:
			_log_line(e.time, "%s 叠加 %s → %d 层" % [
				_side_name(e.side), e.get_name(&"buff"), e.get_int(&"stacks")])
		BattleEvent.DIED:
			_log_line(e.time, "[color=#d9534f]%s 倒下[/color]" % _side_name(e.side))


## 时间戳取【事件自己的时刻】，不是播放光标 ——
## 跳转时一次补上几十条，用光标的话它们会全挤成同一个时间。
func _log_line(at: int, text: String) -> void:
	_ticker.append_text(
		"[color=#5d6470]%5.2f[/color]  %s\n" % [StatMath.to_float(at), text]
	)
	if _ticker.get_line_count() > 200:
		_ticker.clear()


func _side_name(side: int) -> String:
	return _names[side] if side >= 0 and side < _names.size() else "全局"
#endregion


#region 界面
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	_clock = _label("0.00 秒", 16, UiPalette.DIM)
	header.add_child(_clock)
	_verdict = _label("", 16, UiPalette.FG)
	header.add_child(_verdict)

	var arena := HBoxContainer.new()
	arena.add_theme_constant_override("separation", 16)
	root.add_child(arena)
	for i in 2:
		var p := CombatantPanel.new()
		p.label_font = label_font
		p.display_name = _names[i]
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.buff_hovered.connect(_on_buff_hovered)
		p.buff_unhovered.connect(_on_buff_unhovered)
		arena.add_child(p)
		_panels.append(p)

	_ticker = RichTextLabel.new()
	_ticker.bbcode_enabled = true
	_ticker.scroll_following = true
	_ticker.custom_minimum_size = Vector2(0, 150)
	_ticker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticker.add_theme_font_override("normal_font", label_font)
	_ticker.add_theme_font_size_override("normal_font_size", 13)
	root.add_child(_ticker)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	_play_btn = _button("暂停", toggle_play)
	bar.add_child(_play_btn)
	_speed_btn = _button("1×", cycle_speed)
	bar.add_child(_speed_btn)
	bar.add_child(_button("跳过", skip_to_end))
	bar.add_child(_label("战斗中只能看与跳过 —— 结果在开打那一瞬就已经算完了；停在 buff 图标上看效果", 12, UiPalette.DIM))
	_tip = HoverTip.new(label_font)
	add_child(_tip)


func _sync_buttons() -> void:
	if _play_btn == null:
		return
	var done := _result != null and _cursor >= _result.log.size()
	_play_btn.text = "重播" if done else ("暂停" if _playing else "播放")
	_speed_btn.text = "%d×" % int(SPEEDS[_speed_idx])


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", label_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", label_font)
	b.pressed.connect(handler)
	return b
#endregion
