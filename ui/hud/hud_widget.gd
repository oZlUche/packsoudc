## 150（作者定，四项待定按推荐）：地图屏上的一种读数（倒计时、行动点、体力、货币……）—— 一个能单独摆放的组件。
##
## 组件只管「写什么」：[method text_of] 给一行字，空串 = 这会儿没什么可显示的（轻装不显示负重、这一章没有倒计时），组件就藏起来。
## 「摆在哪」归 [HudHost] 按布局（[HudLayout]）管。大小两档：[enum Tier] 的 SMALL = 14 号，LARGE = 34 号一行大字。
## 新加一种 = 一个子类 + [HudWidgets] 登记一行。底与字走主题变体 `PanelHud` / `LabelHud` / `LabelHudLarge`（121），换皮只改这里与主题
class_name HudWidget
extends PanelContainer

## DOUBLE（作者 2026-10-12）：小档的 200%，地图顶栏那一排用它
enum Tier { LARGE, SMALL, DOUBLE }

## 布局文件里引用的名字
var id: StringName = &""
var tier: Tier = Tier.SMALL
var run: RunState = null
## 所在的屏（悬浮窗、flow 从这里取）
var screen: Control = null
## 布局说的显隐（「摆读数」模式里右键切）
var shown: bool = true
## 「摆读数」模式：显示虚线框与 id、能拖；藏着的也画出来（半透明）
var editing: bool = false
var host: Node = null
## 190：宿主排进顶端栏的槽（`bar_*`）时置 true，排到别处置 false（[method set_in_bar]）
var in_bar: bool = false

var _text: Label
var _drag_from: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _init() -> void:
	theme_type_variation = UiTheme.PANEL_HUD
	UiTheme.apply_tone(self, UiTheme.PANEL_HUD)     # 157 补：每块底按深浅挂字色
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)
	set_tier(Tier.SMALL)


## 接上一局：订阅 [method watch] 给的信号（参数不管），然后刷一次
func setup(p_run: RunState, p_screen: Control) -> void:
	run = p_run
	screen = p_screen
	if run != null:
		for sig in watch():
			sig.connect(_poke)
	refresh()


## 子类给：这些信号一响就刷新。地图屏自己也会整体刷（[method HudHost.refresh]），这里是组件自己的那份
func watch() -> Array[Signal]:
	return []


## 子类给：这一行写什么。空串 = 现在不显示
func text_of() -> String:
	return ""


## 子类可改：占不占地图的边（186：提示行一会儿出一会儿没，不让地图跟着挪）
func takes_space() -> bool:
	return true


## 子类给：中文名（摆读数时没内容的组件显示它）
func title() -> String:
	return String(id)


## 166：在字的左边加一枚图标（货币的金币、信仰的徽记）：字和图标排成一行
func _prepend_icon(icon: Control) -> void:
	var row := UiTheme.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remove_child(_text)
	add_child(row)
	row.add_child(icon)
	row.add_child(_text)
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## 宿主换掉这件之前叫它（150 补 1：装着屏幕那块控件的组件把控件还回去，别跟着组件一起释放）
func release() -> void:
	pass


## 子类可改：文字以外的画法（倒计时的颜色随剩余变）
func _paint() -> void:
	pass


func _poke(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	poke()


## 该刷了：宿主按住着（231 补充二，[method HudHost.hold]）就只记下，放开时再刷
func poke() -> void:
	if host is HudHost and (host as HudHost).held:
		_dirty = true
		return
	refresh()


## 231 补充二：按住期间有没有攒下要刷的
var _dirty := false
## 滚数用：现在显示到几（[method roll_value] 有数的件）
var _roll_tween: Tween = null


## 宿主放开：攒下了就刷；[param roll] 且这件有数可滚（[method roll_value]）、动效开着，就从旧数滚到新数（0.6 秒）
func release_hold(roll: bool) -> void:
	if not _dirty:
		return
	_dirty = false
	var from := _shown_value
	refresh()
	var to := roll_value()
	if not roll or from < 0 or to < 0 or from == to or not _motion() or not is_inside_tree():
		return
	if _roll_tween != null:
		_roll_tween.kill()
	_text.text = text_at(from)
	_roll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_roll_tween.tween_method(func(v: float): _text.text = text_at(roundi(v)), float(from), float(to), ROLL_SEC)


const ROLL_SEC := 0.6


## 子类可改：这件显示的那个数（滚数用）；没有 -1
func roll_value() -> int:
	return -1


## 子类可改：数是 [param v] 时这一行写什么（滚数的中间帧）
func text_at(_v: int) -> String:
	return text_of()


## 上一次刷时的数（[method roll_value]；没有 -1）
var _shown_value := -1


func _motion() -> bool:
	var flow = screen.get("flow") if screen != null else null
	return UiMotion.enabled(flow.settings if flow != null else null)


func refresh() -> void:
	if _roll_tween != null:
		_roll_tween.kill()
		_roll_tween = null
	_shown_value = roll_value() if run != null else -1
	var t := text_of() if run != null else ""
	_text.text = t if t != "" or not editing else "（%s）" % title()     # 摆读数时没内容的也露个名字，好拖
	_paint()
	_sync_visible()
	queue_redraw()


## 现在显示的那行字（测试读它）
func text() -> String:
	return _text.text


## 这一刻有没有东西可显示（不看布局的显隐）
func has_content() -> bool:
	return run != null and text_of() != ""


func set_tier(t: Tier) -> void:
	tier = t
	_text.theme_type_variation = {Tier.LARGE: UiTheme.LABEL_HUD_LARGE, Tier.DOUBLE: UiTheme.LABEL_HUD_DOUBLE}.get(t, UiTheme.LABEL_HUD)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if t == Tier.LARGE else HORIZONTAL_ALIGNMENT_LEFT
	reset_size()


func set_editing(on: bool) -> void:
	editing = on
	mouse_filter = Control.MOUSE_FILTER_STOP if on else _idle_mouse_filter()
	modulate.a = 0.45 if on and not shown else 1.0
	refresh()


## 190：宿主排完一遍告诉这件在不在栏里。235：石刻栏皮上的件都带自己的凹槽（长槽与铜点退役），没变就不动
func set_in_bar(on: bool) -> void:
	if in_bar == on:
		return
	in_bar = on
	_bar_changed()


## 子类可改：进出栏之后（日晷在栏里画在栏皮的晷面上）
func _bar_changed() -> void:
	pass


## 子类可改：教程挖洞指的那块（屏幕坐标）；默认就是这一件的包围盒
func focus_rect() -> Rect2:
	return get_global_rect()


## 平时要不要接鼠标（信仰那件要开悬浮窗）
func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_IGNORE


func _sync_visible() -> void:
	visible = editing or (shown and _text.text != "")


#region 摆读数
func _gui_input(event: InputEvent) -> void:
	if not editing or host == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = true
				_drag_from = get_global_mouse_position() - global_position
			MOUSE_BUTTON_RIGHT:
				host.toggle_shown(self)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				host.toggle_tier(self)
		accept_event()
	elif mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _dragging:
		_dragging = false
		host.drop(self)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_from
		accept_event()


func _draw() -> void:
	if not editing:
		return
	var r := Rect2(Vector2.ONE, size - Vector2(2, 2))
	var col := UiPalette.STAMINA
	for pair in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		draw_dashed_line(pair[0], pair[1], col, 1.0, 4.0)
	var font := get_theme_default_font()
	if font != null:
		draw_string(font, Vector2(4, 11), String(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
#endregion
