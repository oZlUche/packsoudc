## 160（作者定）：腰带的圆槽 —— 一排圆，一格一种随身技能（[BeltModule]），圆里画图标（没图画名字的头一个字），
## 右下角一个小圆标写还有几个；空槽一个淡的小圆点。双击一个圆 = 用一个（[member on_use]，用不了的原因走告示卷轴 —— 226 批一删了圆上方的飘字）。
## 没有拖进拖出：随身技能不是道具，不落地、不进包。悬停看名字、说明与什么时候能用。
## 圆槽底图 `assets/ui/belt_slot.png`（72 px 一张圆底，有就贴，没有画圆）。
## 232（作者 19:23 选 6）：1–6 格换成一整张弯皮带挂皮袋（`belt/belt_<n>`，圆心读 `belt/layout.json`，袋面的压花圆就是槽）；
## 超过 6 格或缺图退回一排直圆槽
class_name BeltSlots
extends Control

## 圆的直径与圆之间的空（166：作者要更显眼，56 → 72）
const SLOT := 72.0
const GAP := 12.0
const BADGE := 24.0
const SLOT_ART := "res://assets/ui/belt_slot.png"
## 232：弯皮带的图与摆位表
const BELT_DIR := "belt/"
## 双击 / 悬停算进这一格的半径
const HIT := 36.0
## 弯皮带上没图标时那个字的墨色
const INK := Color("2e2219")

static var _belt_layouts: Dictionary = {}
static var _belt_loaded := false

var module: BeltModule = null
## 用一个：`func(skill_id) -> String`（空串 = 用了，否则是原因）。没接 = 直接调模块
var on_use: Callable = Callable()
var font: Font = null

var _slot_tex: Texture2D = null
## 最近一句用不了的原因（测试读 [method flashed]）
var _last_flash := ""


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
	var lay := _layout()
	custom_minimum_size = Vector2(lay["size"][0], lay["size"][1]) if not lay.is_empty() else Vector2(n * SLOT + maxi(0, n - 1) * GAP, SLOT)
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


## 第 [param i] 个圆的圆心（本控件内像素）：弯皮带读表，直圆槽一排
func slot_center(i: int) -> Vector2:
	var lay := _layout()
	if not lay.is_empty() and i >= 0 and i < (lay["centers"] as Array).size():
		var c: Array = lay["centers"][i]
		return Vector2(float(c[0]), float(c[1]))
	return Vector2(SLOT * 0.5 + i * (SLOT + GAP), SLOT * 0.5)


## 本控件内一点落在哪个圆里（按圆心距 ≤ [constant HIT]）；不在圆里 -1
func slot_at(local: Vector2) -> int:
	for i in slot_count():
		if local.distance_to(slot_center(i)) <= HIT:
			return i
	return -1


## 232：现在是不是弯皮带（格数有图）
func curved() -> bool:
	return not _layout().is_empty()


## 这个格数的弯皮带摆位 {file, size, centers}；没有（超过 6 格、缺图）空
func _layout() -> Dictionary:
	var lay: Dictionary = belt_layouts().get(str(slot_count()), {})
	if lay.is_empty() or UiTheme.art_cached(BELT_DIR + String(lay["file"]).get_basename()) == null:
		return {}
	return lay


## `belt/layout.json` 的 layouts（读一次）
static func belt_layouts() -> Dictionary:
	if not _belt_loaded:
		_belt_loaded = true
		_belt_layouts = UiTheme.art_meta(BELT_DIR + "layout").get("layouts", {})
	return _belt_layouts


## 用第 [param i] 格的那一种。返回原因（空串 = 用了）；用不了走告示
func use_slot(i: int) -> String:
	var sid := skill_at(i)
	if sid == &"":
		return UiText.t("belt.empty_slot")
	var why: String = on_use.call(sid) if on_use.is_valid() else module.use(sid)
	if why != "":
		var def := BeltSkillDef.find(sid)
		flash(UiText.t("belt.flash") % [Names.of(def) if def != null else String(sid), why], i)
	return why


## 226 批一：用不了的原因走告示卷轴（[NoticeLayer]），不再在圆上方飘字。[param _at_slot] 留着给调用方
func flash(text: String, _at_slot: int = 0) -> void:
	_last_flash = text
	NoticeLayer.post(self, text, true)


## 最近一句（测试读）
func flashed() -> String:
	return _last_flash


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
		return UiText.t("belt.empty_tip") if slot_at(at) >= 0 else ""
	return UiText.t("belt.tip") % [Names.of(def), module.count_of(def.id), Names.description_of(def), def.describe()]


func _draw() -> void:
	var f := font if font != null else get_theme_default_font()
	var r := SLOT * 0.5
	var lay := _layout()
	var bent := not lay.is_empty()
	if bent:
		draw_texture(UiTheme.art_cached(BELT_DIR + String(lay["file"]).get_basename()), Vector2.ZERO)
	for i in slot_count():
		var c := slot_center(i)
		if bent:
			pass     # 袋面的压花圆就是槽
		elif _slot_tex != null:
			draw_texture_rect(_slot_tex, Rect2(c - Vector2(r, r), Vector2(SLOT, SLOT)), false)
		else:
			draw_circle(c, r, UiPalette.PANEL.darkened(0.2))
			draw_arc(c, r - 1.0, 0.0, TAU, 48, UiPalette.LINE.lightened(0.35), 2.0, true)
		var sid := skill_at(i)
		if sid == &"":
			draw_circle(c, 3.0, Color(UiPalette.DIM, 0.45))
			continue
		var def := BeltSkillDef.find(sid)
		if not bent:
			draw_circle(c, r - 5.0, Color(UiPalette.GRANT, 0.28))
		var icon := def.icon() if def != null else null
		if icon != null:
			var s := SLOT - 16.0
			draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		elif f != null:
			var glyph := (def.display_name if def != null else String(sid)).left(1)
			var size := 24
			var w := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			draw_string(f, c + Vector2(-w.x * 0.5, size * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK if bent else UiPalette.FG)
		# 右下角的数量小圆标
		var b := c + Vector2(r * 0.68, r * 0.68)
		draw_circle(b, BADGE * 0.5, UiPalette.STAMINA)
		draw_arc(b, BADGE * 0.5, 0.0, TAU, 24, UiPalette.BG, 1.5, true)
		if f != null:
			var n := str(module.count_of(sid))
			var nw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(f, b + Vector2(-nw.x * 0.5, 4.5), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiPalette.BTN_PRIMARY_TEXT)
