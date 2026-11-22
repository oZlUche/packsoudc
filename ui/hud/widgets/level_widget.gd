## 382 A（作者定）：顶端栏日晷右边的等级格 —— 黄铜星 + 等级数；欠着选牌时右上角挂红点写张数（超过 9 写「9+」），点它打开选牌。
## 停上去开悬浮窗：这一级的经验值与怎么涨。经验值本身画在栏下沿的透明条上（[code]xp_bar_widget.gd[/code]）
extends HudWidget

const STAR := 26.0
const BRASS := Color("c9a04e")
const DOT := 18.0
const DOT_RED := Color("c8302a")

var _star: Control


func _init() -> void:
	super()
	_star = Control.new()
	_star.custom_minimum_size = Vector2.ONE * STAR
	_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star.draw.connect(_draw_star)
	_prepend_icon(_star)


func title() -> String:
	return "等级"


func _module() -> LevelModule:
	return LevelModule.of(run) if run != null else null


func watch() -> Array[Signal]:
	var lv := _module()
	return ([lv.level_changed] if lv != null else []) as Array[Signal]


func text_of() -> String:
	var lv := _module()
	return str(lv.level()) if lv != null else ""


## 欠着几次选牌（红点上写的数）
func pending() -> int:
	var lv := _module()
	return lv.pending() if lv != null else 0


## 红点上的字：超过 9 写「9+」
static func dot_text(n: int) -> String:
	return "9+" if n > 9 else str(n)


## 这一级灌了几成（满级 = 满）
func fill() -> float:
	var lv := _module()
	if lv == null:
		return 0.0
	var p := lv.progress()
	return 1.0 if p.y <= 0 else clampf(float(p.x) / float(p.y), 0.0, 1.0)


## 悬浮窗：第一行「Lv.N　经验值 a / b」（满级写满级），下面是怎么涨
func tip_text() -> String:
	var lv := _module()
	if lv == null:
		return ""
	var p := lv.progress()
	var head := UiText.t("hud.level") % lv.level() + UiText.t("tip.gap") + (UiText.t("hud.level_max") if p.y <= 0 else UiText.t("hud.level_xp") % [p.x, p.y])
	if lv.pending() > 0:
		head += UiText.t("tip.gap") + UiText.t("hud.level_pending") % lv.pending()
	return head + "\n" + UiText.t("hud.level_tip")


func refresh() -> void:
	super()
	queue_redraw()


func _draw_star() -> void:
	var c := Vector2.ONE * STAR * 0.5
	var pts := PackedVector2Array()
	for i in 10:
		var r := STAR * (0.5 if i % 2 == 0 else 0.22)
		var a := -PI / 2.0 + PI * float(i) / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_star.draw_colored_polygon(pts, BRASS)


func _draw() -> void:
	super()
	var n := pending()
	if n <= 0 or editing:
		return
	var center := Vector2(size.x - DOT * 0.35, DOT * 0.35)
	draw_circle(center, DOT * 0.5, DOT_RED)
	var f := UiPalette.cjk_font_bold()
	var s := dot_text(n)
	var px := 12 if s.length() == 1 else 10
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, center + Vector2(-w * 0.5, px * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP


## 点一下：欠着选牌就打开选牌（摆读数时归基类拖）
func _gui_input(event: InputEvent) -> void:
	if editing:
		super(event)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and screen != null and screen.has_method("show_level_pick"):
		screen.call("show_level_pick")
		accept_event()


func _ready() -> void:
	mouse_filter = _idle_mouse_filter()
	mouse_entered.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null and run != null and not editing:
			tip.show_text(tip_text(), global_position + Vector2(0, size.y)))
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())
