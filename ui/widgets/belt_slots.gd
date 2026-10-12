## 160（作者定）：腰带的圆槽 —— 一排圆，一格一种随身技能（[BeltModule]），圆里画图标（没图画名字的头一个字），
## 右下角一个小圆标写还有几个；空槽一个淡的小圆点。双击一个圆 = 用一个（[member on_use]，用不了的原因在圆的上方飘一行 1.5 秒）。
## 没有拖进拖出：随身技能不是道具，不落地、不进包。悬停看名字、说明与什么时候能用。
## 圆槽底图 `assets/ui/belt_slot.png`（56 px 一张圆底，有就贴，没有画圆）
class_name BeltSlots
extends Control

## 圆的直径与圆之间的空
const SLOT := 56.0
const GAP := 10.0
const BADGE := 20.0
const SLOT_ART := "res://assets/ui/belt_slot.png"
const FLOAT_SEC := 1.5

var module: BeltModule = null
## 用一个：`func(skill_id) -> String`（空串 = 用了，否则是原因）。没接 = 直接调模块
var on_use: Callable = Callable()
var font: Font = null

var _slot_tex: Texture2D = null
var _float: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_tex = load(SLOT_ART) as Texture2D if ResourceLoader.exists(SLOT_ART) else null


func bind(p_module: BeltModule) -> void:
	if module != null and module.changed.is_connected(_on_changed):
		module.changed.disconnect(_on_changed)
	module = p_module
	if module != null:
		module.changed.connect(_on_changed)
	_on_changed()


func _on_changed() -> void:
	var n := slot_count()
	custom_minimum_size = Vector2(n * SLOT + maxi(0, n - 1) * GAP, SLOT)
	update_minimum_size()
	queue_redraw()


func slot_count() -> int:
	return module.slot_count() if module != null else 0


## 第 [param i] 格里的随身技能 id（空格 &""）
func skill_at(i: int) -> StringName:
	if module == null:
		return &""
	var list := module.ids()
	return list[i] if i >= 0 and i < list.size() else &""


## 第 [param i] 个圆的圆心（本控件内像素）
func slot_center(i: int) -> Vector2:
	return Vector2(SLOT * 0.5 + i * (SLOT + GAP), SLOT * 0.5)


## 本控件内一点落在哪个圆里（按圆心距 ≤ 半径）；不在圆里 -1
func slot_at(local: Vector2) -> int:
	for i in slot_count():
		if local.distance_to(slot_center(i)) <= SLOT * 0.5:
			return i
	return -1


## 用第 [param i] 格的那一种。返回原因（空串 = 用了）；用不了在圆上方飘字
func use_slot(i: int) -> String:
	var sid := skill_at(i)
	if sid == &"":
		return "这一格是空的"
	var why: String = on_use.call(sid) if on_use.is_valid() else module.use(sid)
	if why != "":
		var def := BeltSkillDef.find(sid)
		flash("%s：%s" % [def.display_name if def != null else String(sid), why], i)
	return why


## 圆上方飘一行字（[constant FLOAT_SEC] 秒）
func flash(text: String, at_slot: int = 0) -> void:
	if _float == null:
		_float = UiTheme.make_label("", 13, UiPalette.STAMINA)
		_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_float)
	_float.text = text
	_float.modulate.a = 1.0
	_float.reset_size()
	_float.position = Vector2(slot_center(at_slot).x - _float.size.x * 0.5, -_float.size.y - 4)
	var room := size.x - _float.size.x     # 字比圆槽宽：右对齐贴着腰带右边（腰带默认在屏幕右下角）
	_float.position.x = clampf(_float.position.x, minf(0.0, room), maxf(0.0, room))
	_float.visible = true
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_interval(FLOAT_SEC * 0.6)
		tw.tween_property(_float, "modulate:a", 0.0, FLOAT_SEC * 0.4)


## 现在飘着的那行字（测试读）
func flashed() -> String:
	return _float.text if _float != null and _float.visible and _float.modulate.a > 0.0 else ""


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or not mb.double_click:
		return
	var i := slot_at(mb.position)
	if i >= 0:
		use_slot(i)
		accept_event()


func _get_tooltip(at: Vector2) -> String:
	var def := BeltSkillDef.find(skill_at(slot_at(at)))
	if def == null:
		return "腰带：空格" if slot_at(at) >= 0 else ""
	return "%s ×%d\n%s\n%s\n双击使用" % [def.display_name, module.count_of(def.id), def.description, def.describe()]


func _draw() -> void:
	var f := font if font != null else get_theme_default_font()
	var r := SLOT * 0.5
	for i in slot_count():
		var c := slot_center(i)
		if _slot_tex != null:
			draw_texture_rect(_slot_tex, Rect2(c - Vector2(r, r), Vector2(SLOT, SLOT)), false)
		else:
			draw_circle(c, r, UiPalette.PANEL.darkened(0.2))
			draw_arc(c, r - 1.0, 0.0, TAU, 48, UiPalette.LINE.lightened(0.35), 2.0, true)
		var sid := skill_at(i)
		if sid == &"":
			draw_circle(c, 3.0, Color(UiPalette.DIM, 0.45))
			continue
		var def := BeltSkillDef.find(sid)
		draw_circle(c, r - 5.0, Color(UiPalette.GRANT, 0.28))
		var icon := def.icon() if def != null else null
		if icon != null:
			var s := SLOT - 16.0
			draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		elif f != null:
			var glyph := (def.display_name if def != null else String(sid)).left(1)
			var size := 24
			var w := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			draw_string(f, c + Vector2(-w.x * 0.5, size * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiPalette.FG)
		# 右下角的数量小圆标
		var b := c + Vector2(r * 0.68, r * 0.68)
		draw_circle(b, BADGE * 0.5, UiPalette.STAMINA)
		draw_arc(b, BADGE * 0.5, 0.0, TAU, 24, UiPalette.BG, 1.5, true)
		if f != null:
			var n := str(module.count_of(sid))
			var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(f, b + Vector2(-nw.x * 0.5, 4.5), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.BTN_PRIMARY_TEXT)
