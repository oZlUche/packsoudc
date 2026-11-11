## 282（作者 2026-11-05 12:42）：站在商店 / 集市散货摊 / 铁匠铺里的 NPC —— 一块头像（[PortraitSlot]，图在 `assets/portraits/npcs/`），
## 悬停微亮，点一下弹一张小纸条说一句（[NpcChatter.talk]）；纸条右下角「……」= 下一句，点别处收起。不打断买卖（纸条不挡拖拽）。
## 纸条默认贴头像右边，[member note_above] 贴上方（散货摊，复测 v5.29：右边压到柜台上的货）
## 名字作者填了才写在纸条左上角；台词空着时纸条上只有「……」
class_name NpcBadge
extends Control

const SIDE := 96
const NOTE_W := 300.0
const NOTE_FONT := 17
const NAME_FONT := 14
const HOVER := Color(1.12, 1.12, 1.12)
## 纸条比头像高出的 z（局内商店整页在 z 100 上，纸条要跟着抬上去）
const NOTE_Z := 20
## 300 §2.3 纸条图：`npc/note_l|r|b`（尖角在左 / 右 / 下）+ `npc/note.json`（每种摆法的九宫格边、外扩、内边距；字色；间距）；没图照旧用小牌皮
const NOTE_ART := "npc/note"

var npc: StringName = &""
var meta: MetaState = null
var items: ItemDatabase = null
## 局内商店的那一局（基地是 null）
var run: RunState = null
## 专属对话给了道具时调 `func(item_id: StringName)`（页面说一句「进了仓库」）
var on_given: Callable = Callable()
var slot: PortraitSlot = null
var note: PanelContainer = null
var line_label: Label = null
var more_btn: Button = null
var _name_label: Label = null
var _rng := RandomNumberGenerator.new()
## 最近一次说的（测试看）
var last: Dictionary = {}
## 纸条贴在头像上方（散货摊：头像右边是柜台上的货）；上方放不下照旧贴旁边
var note_above := false
var _note_boxes := {}
var _note_side := ""


static func make(p_npc: StringName, p_meta: MetaState, p_items: ItemDatabase, p_run: RunState = null, side: int = SIDE) -> NpcBadge:
	var b := NpcBadge.new()
	b.npc = p_npc
	b.meta = p_meta
	b.items = p_items
	b.run = p_run
	b._build(side)
	return b


static func face_of(def: NpcDef) -> Texture2D:
	if def == null or def.portrait == &"":
		return null
	var path := "res://assets/portraits/npcs/%s.png" % def.portrait
	return load(path) if ResourceLoader.exists(path) else null


func _build(side: int) -> void:
	_rng.randomize()
	var def := NpcChatter.get_def(npc)
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot = PortraitSlot.new(side, face_of(def), true)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	mouse_entered.connect(func(): slot.modulate = HOVER)
	mouse_exited.connect(func(): slot.modulate = Color.WHITE)
	note = PanelContainer.new()
	note.theme_type_variation = UiTheme.PANEL_HOME_CHIP
	var nm := UiTheme.art_meta(NOTE_ART)
	UiTheme.set_tone(note, StringName(String(nm.get("tone", "light"))) if _note_box("l") != null else UiTheme.tone_of(UiTheme.PANEL_HOME_CHIP))
	var ink := Color(String(nm.get("ink", "#2e2219"))) if _note_box("l") != null else UiTheme.INK
	note.visible = false
	note.top_level = true     # 不占页面的位，压在别的东西上面
	note.z_as_relative = false     # top_level 不跟父节点的 z 走：开纸条时按头像实际的 z 再加 NOTE_Z
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	note.custom_minimum_size.x = NOTE_W
	var col := UiTheme.vbox(4)
	note.add_child(col)
	var who := Names.of(def) if def != null else ""
	if who != "":
		_name_label = UiTheme.make_label(who, NAME_FONT, Color(String(nm.get("name_ink", "#2e2219"))) if _note_box("l") != null else UiTheme.INK)
		col.add_child(_name_label)
	line_label = UiTheme.make_label("", NOTE_FONT, ink)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size.x = NOTE_W - 24.0
	col.add_child(line_label)
	more_btn = Button.new()
	more_btn.text = UiText.t("npc.more")
	more_btn.flat = true
	more_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var more_ink := Color(String(nm.get("more_ink", "#2e2219"))) if _note_box("l") != null else UiTheme.INK
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		more_btn.add_theme_color_override(k, more_ink)
	more_btn.pressed.connect(talk)
	col.add_child(more_btn)
	add_child(note)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		talk()
		accept_event()


## 点外面就收起纸条（点头像、点纸条不算）
func _input(event: InputEvent) -> void:
	if note == null or not note.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position
		if not note.get_global_rect().has_point(p) and not get_global_rect().has_point(p):
			close()


## 300 §2.2：进屏自动问候一句（局内商店开）。只在第一次进树时说
var greet_on_enter := false
var _greeted := false


func _ready() -> void:
	if greet_on_enter and not _greeted:
		greet.call_deferred()


## 300 §2.2：说一句问候（纸条同 [method talk]）；这位没有问候句返回 false
func greet() -> bool:
	_greeted = true
	var line := NpcChatter.greet(NpcChatter.get_def(npc), _rng)
	if line == null:
		return false
	last = {"text": Names.pick(line.texts, line.text), "special": &"", "given": &"", "greet": line.id}
	_show_line(String(last["text"]))
	return true


## 说一句：专属对话优先，否则掷一句闲话；纸条贴在头像旁边（右边放不下就放左边）
func talk() -> void:
	last = NpcChatter.talk(npc, meta, items, _rng, run)
	if last.is_empty():
		close()
		return
	_show_line(String(last.get("text", "")))
	var given := StringName(String(last.get("given", "")))
	if given != &"" and on_given.is_valid():
		on_given.call(given)


## 摆在整页（[MarketStage]）缩放后的矩形里：取短边做正方，靠矩形底边居中
func fit(r: Rect2) -> void:
	var side := minf(r.size.x, r.size.y)
	custom_minimum_size = Vector2(side, side)
	slot.custom_minimum_size = custom_minimum_size
	position = Vector2(r.position.x + (r.size.x - side) * 0.5, r.end.y - side)
	size = custom_minimum_size


func close() -> void:
	if note != null:
		note.visible = false


## 画的时候真正用的 z：一路往上加，碰到不相对的或 top_level 的就停
static func abs_z(ci: CanvasItem) -> int:
	var z := 0
	var n: Node = ci
	while n is CanvasItem:
		var c := n as CanvasItem
		z += c.z_index
		if not c.z_as_relative or c.top_level:
			break
		n = c.get_parent()
	return z


func is_open() -> bool:
	return note != null and note.visible


## 300 §2.3：纸条图（尖角在左 / 右 / 下三张）的九宫格；边条平铺（TILE_FIT），毛边、针脚接得上
func _note_box(side: String) -> StyleBoxTexture:
	if _note_boxes.has(side):
		return _note_boxes[side]
	var tex := UiTheme.art_cached("%s_%s" % [NOTE_ART, side])
	var spec: Dictionary = UiTheme.art_meta(NOTE_ART).get(side, {})
	if tex == null or spec.is_empty():
		return null
	var s := UiTheme.nine_box(tex, spec["margin"], spec["content"])
	var ex: Array = spec["expand"]
	s.expand_margin_left = float(ex[0])
	s.expand_margin_top = float(ex[1])
	s.expand_margin_right = float(ex[2])
	s.expand_margin_bottom = float(ex[3])
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_note_boxes[side] = s
	return s


func _use_side(side: String) -> void:
	var box := _note_box(side)
	if box == null or _note_side == side:
		return
	_note_side = side
	note.add_theme_stylebox_override("panel", box)
	note.reset_size()


func _seat_note() -> void:
	var r := get_global_rect()
	var gap := float(UiTheme.art_meta(NOTE_ART).get("gap", 8.0)) if _note_box("l") != null else 8.0
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1e9, 1e9)
	_use_side("b" if note_above else "l")
	var sz := note.get_combined_minimum_size()
	if note_above and r.position.y - gap - sz.y >= 0.0:
		note.global_position = Vector2(clampf(r.position.x, 0.0, maxf(0.0, view.x - sz.x)), r.position.y - gap - sz.y)
		return
	_use_side("l")
	sz = note.get_combined_minimum_size()
	var x := r.end.x + gap
	if x + sz.x > view.x:
		_use_side("r")
		sz = note.get_combined_minimum_size()
		x = r.position.x - gap - sz.x
	var y := clampf(r.position.y, 0.0, maxf(0.0, view.y - sz.y))
	note.global_position = Vector2(maxf(0.0, x), y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and slot != null:
		slot.size = size
		if is_open():
			_seat_note()


func _show_line(raw: String) -> void:
	var text := KeyNames.expand(raw)     # 284 §3.5：[key=动作] 换成现在绑的键名
	line_label.text = text if text != "" else UiText.t("npc.more")
	line_label.visible = text != ""
	note.z_index = abs_z(self) + NOTE_Z
	note.visible = true
	note.reset_size()
	_seat_note()
