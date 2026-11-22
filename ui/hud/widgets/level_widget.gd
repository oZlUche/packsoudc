## 372：经验值管 —— 顶端栏下面横着一根管子，按这一级攒到的比例灌满；管上写「Lv.N　经验值 a / b」（满级写满级）。
## 停上去开悬浮窗：经验值怎么涨。管子是占位画法（圆角底 + 填充 + 高光），样张定了换图
extends HudWidget

const TUBE := Vector2(360, 22)
const RADIUS := 10.0
const GLASS := Color(1, 1, 1, 0.08)
const EDGE := Color(1, 1, 1, 0.35)
const SHINE := Color(1, 1, 1, 0.18)


func _init() -> void:
	super()
	custom_minimum_size = TUBE
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	self_modulate.a = 0.0     # 不画通用凹槽：管子自己画


func title() -> String:
	return "经验值"


func _module() -> LevelModule:
	return LevelModule.of(run) if run != null else null


func watch() -> Array[Signal]:
	var lv := _module()
	return ([lv.level_changed] if lv != null else []) as Array[Signal]


func text_of() -> String:
	var lv := _module()
	if lv == null:
		return ""
	var p := lv.progress()
	var head := UiText.t("hud.level") % lv.level()
	var tail := UiText.t("tip.gap") + UiText.t("hud.level_pending") % lv.pending() if lv.pending() > 0 else ""
	if p.y <= 0:
		return head + UiText.t("tip.gap") + UiText.t("hud.level_max") + tail
	return head + UiText.t("tip.gap") + UiText.t("hud.level_xp") % [p.x, p.y] + tail


## 这一级灌了几成（满级 = 满）
func fill() -> float:
	var lv := _module()
	if lv == null:
		return 0.0
	var p := lv.progress()
	return 1.0 if p.y <= 0 else clampf(float(p.x) / float(p.y), 0.0, 1.0)


func set_tier(t: Tier) -> void:
	super(t)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(GLASS, EDGE), r)
	var f := fill()
	if f > 0.0:
		var w := maxf(RADIUS * 2.0, r.size.x * f)
		draw_style_box(_box(Color(UiPalette.FAITH, 0.85), Color(0, 0, 0, 0)), Rect2(r.position, Vector2(w, r.size.y)).grow(-2))
	draw_style_box(_box(SHINE, Color(0, 0, 0, 0)), Rect2(r.position + Vector2(RADIUS, 3), Vector2(r.size.x - RADIUS * 2.0, 3)))
	super()


func _box(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(RADIUS))
	if edge.a > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(1)
	return sb


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
			tip.show_text(UiText.t("hud.level_tip"), global_position + Vector2(0, size.y)))
	mouse_exited.connect(func():
		var tip: HoverTip = screen.get("_tip") if screen != null else null
		if tip != null:
			tip.release())
