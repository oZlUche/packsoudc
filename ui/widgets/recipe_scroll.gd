## 251 补充一 §10.2：铁匠铺点一格配方后，下方弹出的打造界面。补充二 §12.2（作者 10-25 14:21「铁匠铺的合成界面应该是铁砧配色的」）：
## 底是整块铁砧剪影 `smithy/anvil_plate.png`（深底 → 浅字 [constant UiPalette.ANVIL_INK]；缺图是铁灰平底 [constant UiPalette.ANVIL_IRON]），
## 内容摆在砧面上（`smithy/layout.json` 的 `face` 相对 `scroll` 的那块），整页缩放时 [method fit] 跟着缩；砧顶一个小尖 `anvil_pointer` 对准选中的格子（[member pointer_x]）。
## 一行：产物（带框小棋盘）｜产物名 +「需要材料」+ 每样素材「小图 + 有几 / 要几」（不够的暖红 [constant UiPalette.WARN_ON_DARK]）｜「工钱」金币 + 数字、
## 补图（UI替换美术 10-25 15:14 C）：素材摆在一条深色凹槽里，每样一格（照格子区缩小：道具图 + 下面「有几 / 要几」数牌，格与格之间一道格线）；
## 「打造」键 —— 烧红四态图 `smithy/forge_key*.png`（[method IconButton.make_art]，字由代码写：`forge_key.json` 的键面里、粗体浅字深红描边），没图是平键 [constant UiTheme.BUTTON_FORGE]
class_name RecipeScroll
extends PanelContainer

const KEY_DIR := "res://assets/ui/smithy/"
const KEY_ID := "forge_key"
const KEY_META := "smithy/forge_key"
const LAYOUT := "smithy/layout"
const PLATE := "smithy/anvil_plate"
const POINTER := "smithy/anvil_pointer"
## 凹槽里一格素材多大（原尺寸）：格宽、图边长、数牌高
const MAT_W := 76.0
const MAT_ICON := 44.0
const MAT_PLATE_H := 22.0
const MAT_TEXT := 15
const GROOVE := Color("1d1b19")
const GROOVE_SHADE := Color("0e0d0c")
const MAT_PLATE := Color("2c2926")
const MAT_LINE := Color("4a4540")
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
var _groove: PanelContainer = null
var _mats: HBoxContainer = null
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
	_groove = PanelContainer.new()
	_groove.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(_groove)
	_mats = HBoxContainer.new()
	_mats.add_theme_constant_override("separation", 0)
	_groove.add_child(_mats)
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
	var ts := maxi(11, roundi(UiTheme.sz(TEXT_SIZE) * _k))     # 258：按字号档
	for l in [_need, _wage_label]:
		(l as Label).add_theme_font_size_override("font_size", ts)
	_name.add_theme_font_size_override("font_size", maxi(14, roundi(UiTheme.sz(NAME_SIZE) * _k)))
	_wage.font_size = ts
	var g := StyleBoxFlat.new()     # 凹槽：深底、上沿和左沿压暗
	g.bg_color = GROOVE
	g.border_color = GROOVE_SHADE
	g.border_width_top = maxi(1, roundi(3 * _k))
	g.border_width_left = maxi(1, roundi(2 * _k))
	g.border_width_right = 1
	g.set_corner_radius_all(maxi(2, roundi(5 * _k)))
	g.set_content_margin_all(maxf(3.0, 6.0 * _k))
	_groove.add_theme_stylebox_override("panel", g)
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
	var n := _mats.get_child_count()
	for i in n:
		(_mats.get_child(i) as MatSlot).line_right = i < n - 1
	_wage.amount = r.funds
	_wage.short = CoinShort.has(why)     # 「金币不够」：工钱那枚金币变红、斜划一道，不写字
	forge_key.disabled = why != ""
	forge_key.tooltip_text = CoinShort.strip(why)
	forge_key.sync_art()


## 一样素材：凹槽里一格（图 + 「有几 / 要几」数牌，不够的暖红）
func _mat(d: ItemDef, have: int, need: int) -> Control:
	var slot := MatSlot.new()
	slot.def = d
	slot.text = "%d / %d" % [have, need]
	slot.color = _ink if have >= need else _short
	slot.k = _k
	slot.custom_minimum_size = Vector2(MAT_W, MAT_ICON + MAT_PLATE_H + 14.0) * _k
	slot.mouse_filter = Control.MOUSE_FILTER_STOP     # 265：停上去出这一种道具的悬浮窗（[method MatSlot.hover]），可收藏
	return slot


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
	for slot in _mats.get_children():
		out.append((slot as MatSlot).text)
	return out


## 素材那几行的字色（不够的暖红）
func material_colors() -> Array[Color]:
	var out: Array[Color] = []
	for slot in _mats.get_children():
		out.append((slot as MatSlot).color)
	return out


func wage() -> int:
	return _wage.amount


## 凹槽里的一格素材：上面道具图（没图画本色块），下面一块深色数牌写「有几 / 要几」，右边一道格线（最后一格不画）。
## 265（作者 16:43「在铁匠铺的材料栏里面，材料也要可以显示悬浮窗并被收藏」）：停上去出这一种的道具窗（[method HoverTip.show_kind]，右上角收藏丝带），收藏了图右上角一枚星
class MatSlot extends Control:
	var def: ItemDef = null
	var text := ""
	var color := Color.WHITE
	var k := 1.0
	var line_right := true

	func _ready() -> void:
		add_to_group(ItemFavorites.GROUP)
		mouse_entered.connect(hover)
		mouse_exited.connect(unhover)

	func hover() -> void:
		var tip := HoverTip.host_for(self)
		if tip != null and def != null:
			tip.show_kind(def, global_position + Vector2(size.x, 0), get_global_rect())

	func unhover() -> void:
		var tip := HoverTip.host_for(self)
		if tip != null:
			tip.release()

	## 道具图画在哪（格内坐标）
	func icon_rect() -> Rect2:
		var icon := MAT_ICON * k
		return Rect2(Vector2((size.x - icon) * 0.5, 5.0 * k), Vector2(icon, icon))

	func _draw() -> void:
		var pad := 5.0 * k
		var plate_h := MAT_PLATE_H * k
		var icon := MAT_ICON * k
		if line_right:
			draw_line(Vector2(size.x - 0.5, pad), Vector2(size.x - 0.5, size.y - pad), MAT_LINE, 1.0)
		var ir := icon_rect()
		var tex := ItemPainter.art_of(def) if def != null else null
		if tex != null:
			var ts := tex.get_size()
			var f := minf(ir.size.x / ts.x, ir.size.y / ts.y)
			var r := Rect2(Vector2.ZERO, ts * f)
			r.position = ir.get_center() - r.size * 0.5
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(ir.grow(-icon * 0.15), ItemPainter.body_color(def) if def != null else Color.GRAY)
		if def != null and ItemFavorites.has(def.id):
			var side := ItemPainter.LOCK_SIDE * k
			ItemPainter.draw_favorite_badge(self, Rect2(Vector2(ir.end.x - side, ir.position.y), Vector2(side, side)))
		var pr := Rect2(Vector2(pad, size.y - pad - plate_h), Vector2(size.x - pad * 2.0, plate_h))
		draw_rect(pr, MAT_PLATE)
		draw_rect(pr.grow(-0.5), MAT_LINE, false, 1.0)
		var font := UiPalette.cjk_font_bold()
		var fs := maxi(10, roundi(MAT_TEXT * k))
		var y := pr.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(pr.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, fs, color)
