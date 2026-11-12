## 306 定稿（作者 2026-11-12 选 B）：合成确认窗 —— 300 那张纸条（`npc/note_l`，右边放不下换 `npc/note_r`），尖角和小锤同高。
## 自上而下：认识成品才有的名字行 / [甲] + [乙] → [成品] 一排图（不认识 = `fuse/unknown`）/ 红墨「会丢」一行（没有就不写）/ 平签「合成」「取消」。
## 只在点签、按 Esc、点窗外时收（v5.85：离开不收）
class_name FuseNote
extends Control

const NOTE_ART := "npc/note"
const UNKNOWN_ART := "fuse/unknown"
const ROW_H := 64.0
const LINE_GAP := 8
const PIC_GAP := 10
const KEY_GAP := 8
const KEY_SIZE := Vector2(96, 30)
## 窗顶到尖角中心多高（纸条图上的尖角离顶 40）
const TIP_Y := 40.0
## 尖角外扩 14 + 离那一对 14
const SIDE_GAP := 28.0
## content 每边在 json 上再加的
const PAD_X := 6.0
const PAD_Y := 4.0
const BROWN := Color("5a4433")
const RED_INK := Color("a14634")
const BRASS := Color("ecd28a")
const HOVER_LINE := Color("d4a84f")

## 那张纸
var paper: PanelContainer = null
var go_key: Button = null
var cancel_key: Button = null
## 名字行（不认识 = null）与「会丢」行（没有 = null）—— 测试看
var name_label: Label = null
var loss_label: Label = null
## 成品位那张图
var out_pic: TextureRect = null
var _on_go: Callable = Callable()
## 关上时叫一下（棋盘放下那一对的高亮）
var closed: Callable = Callable()


func _init() -> void:
	name = "FuseNote"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## 开窗：[param pair] = 两件合起来的外框（全局），[param hammer_y] = 小锤中心的全局 y；[param loss] 空 = 不写那一行
func open(a: ItemDef, b: ItemDef, out: ItemDef, known: bool, loss: String, pair: Rect2, hammer_y: float, on_go: Callable) -> void:
	close()
	_on_go = on_go
	visible = true
	_fill("l", a, b, out, known, loss)
	paper.reset_size()
	var s := paper.get_combined_minimum_size()
	var view := get_viewport_rect().size if is_inside_tree() else size
	var x := pair.end.x + SIDE_GAP
	if x + s.x > view.x:
		_fill("r", a, b, out, known, loss)
		paper.reset_size()
		s = paper.get_combined_minimum_size()
		x = pair.position.x - SIDE_GAP - s.x
	var y := clampf(hammer_y - TIP_Y, 0.0, maxf(0.0, view.y - s.y))
	paper.global_position = Vector2(x, y)


func is_open() -> bool:
	return visible and paper != null


## 尖角朝哪边（"l" = 在两件右边、尖角朝左）
func side() -> String:
	return String(paper.get_meta("side", "")) if paper != null else ""


func close() -> void:
	if paper != null:
		paper.queue_free()
		paper = null
	go_key = null
	cancel_key = null
	name_label = null
	loss_label = null
	out_pic = null
	var was := visible
	visible = false
	if was and closed.is_valid():
		closed.call()


func go() -> void:
	var f := _on_go
	close()
	if f.is_valid():
		f.call()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and not paper.get_global_rect().has_point(mb.global_position):
		close()


## 拼一张纸（[param side_key] = json 里的 l / r）
func _fill(side_key: String, a: ItemDef, b: ItemDef, out: ItemDef, known: bool, loss: String) -> void:
	if paper != null:
		paper.free()
	var meta := UiTheme.art_meta(NOTE_ART)
	paper = PanelContainer.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.set_meta("side", side_key)
	UiTheme.box_panel(paper, _box(side_key, meta))
	UiTheme.set_tone(paper, UiTheme.TONE_LIGHT)
	add_child(paper)
	var ink := Color(String(meta.get("ink", "#2e2219")))
	var col := UiTheme.vbox(LINE_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(col)
	if known:
		name_label = _label(Names.of(out), 16, Color(String(meta.get("name_ink", "#7a3420"))), true)
		col.add_child(name_label)
	var row := UiTheme.hbox(PIC_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pic(a, false))
	row.add_child(_label("+", 22, BROWN, true))
	row.add_child(_pic(b, false))
	row.add_child(_label("→", 22, BROWN, true))
	out_pic = _pic(out, not known)
	row.add_child(out_pic)
	col.add_child(row)
	if loss != "":
		loss_label = _label(loss, 15, RED_INK, false)
		loss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(loss_label)
	var keys := UiTheme.hbox(KEY_GAP)
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	go_key = _key(UiText.t("fuse.go"), BRASS, ink, ink)
	go_key.pressed.connect(go)
	cancel_key = _key(UiText.t("fuse.cancel"), Color(0, 0, 0, 0), BROWN, BROWN)
	cancel_key.pressed.connect(close)
	keys.add_child(go_key)
	keys.add_child(cancel_key)
	col.add_child(keys)


func _box(side_key: String, meta: Dictionary) -> StyleBoxTexture:
	var tex := UiTheme.art_cached("%s_%s" % [NOTE_ART, side_key])
	var spec: Dictionary = meta.get(side_key, {})
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
	s.content_margin_left += PAD_X
	s.content_margin_right += PAD_X
	s.content_margin_top += PAD_Y
	s.content_margin_bottom += PAD_Y
	return s


func _label(text: String, font_size: int, color: Color, bold: bool) -> Label:
	var l := UiTheme.make_label(text, font_size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold:
		l.theme_type_variation = UiTheme.LABEL_NOTE_TITLE     # 只换粗体；字号、字色是上面给的
	return l


## 一件按格形缩到行高（长边 = [constant ROW_H]）；[param masked] = 不认识，放统一的问号图，见方
func _pic(def: ItemDef, masked: bool) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if masked or def == null or def.shape == null:
		t.texture = UiTheme.art_cached(UNKNOWN_ART)
		t.custom_minimum_size = Vector2.ONE * ROW_H
		return t
	t.texture = ItemPainter.art_of(def, 120.0)
	var s := Vector2(def.shape.size_rotated(0))
	var m := maxf(s.x, s.y)
	t.custom_minimum_size = Vector2(ROW_H * s.x / m, ROW_H * s.y / m)
	return t


func _key(text: String, fill: Color, line: Color, ink: Color) -> Button:
	return UiTheme.flat_key(text, fill, line, HOVER_LINE, ink, KEY_SIZE, 15)
