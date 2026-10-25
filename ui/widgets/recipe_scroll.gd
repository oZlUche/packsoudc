## 251 补充一 §10.2：铁匠铺点一格配方后，下方弹出的打造界面。补充二 §12.2（作者 10-25 14:21「铁匠铺的合成界面应该是铁砧配色的」）：
## 底是整块铁砧剪影 `smithy/anvil_plate.png`（深底 → 浅字 [constant UiPalette.ANVIL_INK]；缺图是铁灰平底 [constant UiPalette.ANVIL_IRON]），
## 内容摆在砧面上（`smithy/layout.json` 的 `face` 相对 `scroll` 的那块），整页缩放时 [method fit] 跟着缩；砧顶一个小尖 `anvil_pointer` 对准选中的格子（[member pointer_x]）。
## 一行：产物（带框小棋盘）｜产物名 +「需要材料」+ 每样素材「小图 + 有几 / 要几」（不够的暖红 [constant UiPalette.WARN_ON_DARK]）｜「工钱」金币 + 数字、
## 「打造」键 —— 烧红四态图 `smithy/forge_key*.png`（[method IconButton.make_art]，字由代码写：`forge_key.json` 的键面里、粗体浅字深红描边），没图是平键 [constant UiTheme.BUTTON_FORGE]
class_name RecipeScroll
extends PanelContainer

const KEY_DIR := "res://assets/ui/smithy/"
const KEY_ID := "forge_key"
const KEY_META := "smithy/forge_key"
const LAYOUT := "smithy/layout"
const PLATE := "smithy/anvil_plate"
const POINTER := "smithy/anvil_pointer"
const MAT_ICON := 30.0
## 原尺寸时各处字号（[method fit] 按整页缩放乘）
const NAME_SIZE := 28
const TEXT_SIZE := 18
const PRODUCT_BOX := 120.0
const PRODUCT_CELL_MAX := 36.0
const KEY_INK := Color("fff6e2")
const KEY_OUTLINE := Color("6a1a0c")
const KEY_OFF_INK := Color("cfc8bc")

var forge_key: IconButton = null
## 小尖横向对准哪里（自己坐标；< 0 = 不画）
var pointer_x := -1.0:
	set(v):
		pointer_x = v
		queue_redraw()
var _k := 1.0
var _product: CenterContainer = null
var _name: Label = null
var _need: Label = null
var _wage_label: Label = null
var _mats: HFlowContainer = null
var _wage: CoinLabel = null
var _font: Font = null
var _ink := UiPalette.ANVIL_INK
var _short := UiPalette.WARN_ON_DARK
var _last: Array = []

static var _theme: Theme = null


static func make(font: Font, on_forge: Callable) -> RecipeScroll:
	var s := RecipeScroll.new()
	s._font = font
	s._build(on_forge)
	return s


## 铁砧上的字色：深底浅字（外面中列的粗布是浅底、挂着墨字小主题 —— 这份把 Label 改回浅色）
static func anvil_theme() -> Theme:
	if _theme == null:
		_theme = UiTheme.bright_text_theme().duplicate() as Theme
		_theme.set_color("font_color", "Label", UiPalette.ANVIL_INK)
		_theme.set_type_variation(UiTheme.LABEL_NOTE_TITLE, "Label")
		_theme.set_color("font_color", UiTheme.LABEL_NOTE_TITLE, UiPalette.ANVIL_INK)
	return _theme


func _build(on_forge: Callable) -> void:
	var lay := UiTheme.art_meta(LAYOUT)
	_ink = Color(String(lay.get("text_light", UiPalette.ANVIL_INK.to_html(false))))
	_short = Color(String(lay.get("text_missing", UiPalette.WARN_ON_DARK.to_html(false))))
	UiTheme.set_tone(self, UiTheme.TONE_DARK)
	theme = anvil_theme()
	var row := UiTheme.hbox(18)
	add_child(row)
	_product = CenterContainer.new()
	row.add_child(_product)
	var info := UiTheme.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	_name = Label.new()
	_name.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	info.add_child(_name)
	_need = Label.new()
	_need.text = UiText.t("smithy.materials")
	info.add_child(_need)
	_mats = HFlowContainer.new()
	_mats.add_theme_constant_override("h_separation", 14)
	_mats.add_theme_constant_override("v_separation", 4)
	info.add_child(_mats)
	var side := UiTheme.vbox(6)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	var wage_row := UiTheme.hbox(8)
	wage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(wage_row)
	_wage_label = Label.new()
	_wage_label.text = UiText.t("smithy.wage")
	wage_row.add_child(_wage_label)
	_wage = CoinLabel.make(0, TEXT_SIZE, _ink)
	wage_row.add_child(_wage)
	forge_key = IconButton.make_art(KEY_DIR, KEY_ID, UiText.t("smithy.forge"), "", on_forge)
	if forge_key.theme_type_variation == UiTheme.BUTTON_ART:
		var km := UiTheme.art_meta(KEY_META)
		var kr: Dictionary = km.get("key_rect", {})
		forge_key.art_label = UiText.t("smithy.forge")     # 图上不带字（中英文）
		forge_key.art_label_rect = Rect2(float(kr.get("x", 0)), float(kr.get("y", 0)), float(kr.get("w", 0)), float(kr.get("h", 0)))
		forge_key.art_label_color = KEY_INK
		forge_key.art_label_outline = KEY_OUTLINE
		forge_key.art_label_disabled_color = KEY_OFF_INK
		forge_key.art_label_drop = 1.0
		forge_key.set_meta(&"art_size", forge_key.custom_minimum_size)
		forge_key.set_meta(&"label_size", int(km.get("font_size", 30)))
	else:
		forge_key.theme_type_variation = UiTheme.BUTTON_FORGE     # 没图：烧亮的铁红平键
		forge_key.custom_minimum_size = Vector2(110, 40)
	side.add_child(forge_key)
	fit(1.0)


## 整页缩放 [param k]：底板贴满自己的矩形（铁砧原图按同一比例缩，不变形），内容缩进砧面那块，字号、打造键跟着缩
func fit(k: float) -> void:
	_k = maxf(0.3, k)
	var lay := UiTheme.art_meta(LAYOUT)
	var sr: Dictionary = lay.get("scroll", {})
	var fr: Dictionary = lay.get("face", {})
	var sw := float(sr.get("w", 1228))
	var sh := float(sr.get("h", 348))
	var face := Rect2(float(fr.get("x", 188)) - float(sr.get("x", 45)), float(fr.get("y", 592)) - float(sr.get("y", 578)), float(fr.get("w", 1060)), float(fr.get("h", 178)))
	if lay.is_empty():
		face = Rect2(143, 14, 1060, 178)
	var box: StyleBox = null
	var plate := UiTheme.art_cached(PLATE)
	if plate != null:
		var t := StyleBoxTexture.new()
		t.texture = plate     # 不切九宫格：底板矩形 = 原图 × k，整张等比缩
		box = t
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = UiPalette.ANVIL_IRON
		flat.set_corner_radius_all(int(10 * _k))
		box = flat
	box.content_margin_left = face.position.x * _k
	box.content_margin_top = face.position.y * _k
	box.content_margin_right = (sw - face.end.x) * _k
	box.content_margin_bottom = (sh - face.end.y) * _k
	add_theme_stylebox_override("panel", box)
	var ts := maxi(11, roundi(TEXT_SIZE * _k))
	for l in [_need, _wage_label]:
		(l as Label).add_theme_font_size_override("font_size", ts)
	_name.add_theme_font_size_override("font_size", maxi(14, roundi(NAME_SIZE * _k)))
	_wage.font_size = ts
	if forge_key.has_meta(&"art_size"):
		var a: Vector2 = forge_key.get_meta(&"art_size")
		forge_key.custom_minimum_size = (a * _k).floor()
		forge_key.art_label_size = maxi(12, roundi(int(forge_key.get_meta(&"label_size")) * _k))
		forge_key.hit_rect = Rect2(forge_key.art_label_rect.position * _k, forge_key.art_label_rect.size * _k)
	if not _last.is_empty():
		callv("show_recipe", _last)


## 换成这一张：产物、名字、每样素材有几 / 要几、工钱；[param why] 空 = 能打（打造键亮）
func show_recipe(r: SmithRecipeDef, items: ItemDatabase, got: Dictionary, why: String) -> void:
	_last = [r, items, got, why]
	UiTheme.clear_children(_product)
	var def := items.get_def(r.output)
	var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
	var box := PRODUCT_BOX * _k
	var cell := floorf(minf(PRODUCT_CELL_MAX * _k, minf(box / size.x, box / size.y)))
	var grid := GridInventory.new(BoardFrame.padded_size(size, cell), 0, false)
	if def != null:
		grid.place(ItemInstance.create(def, 0), Vector2i.ZERO, 0)
	var view := InventoryView.new()
	view.label_font = _font
	view.show_adjacency = false
	view.inventory = grid
	view.cell_px = cell
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_product.add_child(view)
	BoardFrame.wrap(view, "plain")
	_name.text = Names.pick(r.display_names, r.display_name) if r.display_name != "" else (Names.of(def) if def != null else String(r.output))
	UiTheme.clear_children(_mats)
	var keys: Array = r.inputs.keys()
	keys.sort()
	for key in keys:
		var d := items.get_def(StringName(String(key)))
		_mats.add_child(_mat(d, int(got.get(String(key), 0)), int(r.inputs[key])))
	_wage.amount = r.funds
	forge_key.disabled = why != ""
	forge_key.tooltip_text = why
	forge_key.sync_art()


## 一样素材：小图 + 「有几 / 要几」（不够的暖红）
func _mat(d: ItemDef, have: int, need: int) -> Control:
	var row := UiTheme.hbox(4)
	row.tooltip_text = Names.of(d) if d != null else ""
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var px := roundf(MAT_ICON * _k)
	var tex := ItemPainter.art_of(d) if d != null else null
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(px, px)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		var swatch := ColorRect.new()
		swatch.color = ItemPainter.body_color(d) if d != null else Color.GRAY
		swatch.custom_minimum_size = Vector2(px, px) * 0.8
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
	var l := Label.new()
	l.text = "%d / %d" % [have, need]
	l.add_theme_font_size_override("font_size", maxi(11, roundi(TEXT_SIZE * _k)))
	l.add_theme_color_override("font_color", _ink if have >= need else _short)
	row.add_child(l)
	return row


## 砧顶的小尖：底边贴着砧顶、横向对准选中格（[member pointer_x]）
func _draw() -> void:
	if pointer_x < 0.0:
		return
	var p: Dictionary = UiTheme.art_meta(LAYOUT).get("pointer", {})
	var w := float(p.get("w", 40)) * _k
	var h := float(p.get("h", 28)) * _k
	var r := Rect2(Vector2(pointer_x - w * 0.5, -float(p.get("dy", 24)) * _k), Vector2(w, h))
	var tex := UiTheme.art_cached(POINTER)
	if tex != null:
		draw_texture_rect(tex, r, false)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.get_center().x, r.position.y), r.end]), UiPalette.ANVIL_IRON)


## 测试看：现在写的产物名、素材那几行的字、工钱、浅字色
func title() -> String:
	return _name.text


func title_label() -> Label:
	return _name


func material_lines() -> Array[String]:
	var out: Array[String] = []
	for row in _mats.get_children():
		out.append((row.get_child(row.get_child_count() - 1) as Label).text)
	return out


## 素材那几行的字色（不够的暖红）
func material_colors() -> Array[Color]:
	var out: Array[Color] = []
	for row in _mats.get_children():
		out.append((row.get_child(row.get_child_count() - 1) as Label).get_theme_color("font_color"))
	return out


func wage() -> int:
	return _wage.amount
