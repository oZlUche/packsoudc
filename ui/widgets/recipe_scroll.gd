## 251 补充一 §10.2：铁匠铺点一格配方后，下方展开的卷轴 —— 纸身与两头的轴沿用告示卷轴（226，[NoticeScroll] 的 `notice_scroll_paper` / `_roller`）。
## 上一行：产物（带框小棋盘）+ 产物名 + 「需要材料」+ 每样素材「小图 + 有几 / 要几」（不够的铁红字）；
## 下一行：「工钱」+ 金币 + 数字（[CoinLabel]），右端「打造」键 —— 烧亮的铁红：四态图 `assets/ui/smithy/forge_key*.png`（[method IconButton.make_art]，
## 字由代码写），没图之前是平键 [constant UiTheme.BUTTON_FORGE]
class_name RecipeScroll
extends PanelContainer

const KEY_DIR := "res://assets/ui/smithy/"
const KEY_ID := "forge_key"
const MAT_ICON := 28.0
const PAD := Vector4(30, 12, 30, 12)
const SHORT := Color("a8331a")

var forge_key: IconButton = null
var _product: CenterContainer = null
var _name: Label = null
var _mats: HFlowContainer = null
var _wage: CoinLabel = null
var _font: Font = null


static func make(font: Font, on_forge: Callable) -> RecipeScroll:
	var s := RecipeScroll.new()
	s._font = font
	s._build(on_forge)
	return s


func _build(on_forge: Callable) -> void:
	var paper := UiTheme.art_box(NoticeScroll.PAPER)
	var box: StyleBox = paper if paper != null else _flat()
	box.content_margin_left = PAD.x
	box.content_margin_top = PAD.y
	box.content_margin_right = PAD.z
	box.content_margin_bottom = PAD.w
	add_theme_stylebox_override("panel", box)
	UiTheme.set_tone(self, UiTheme.TONE_LIGHT)
	var col := UiTheme.vbox(8)
	add_child(col)
	var top := UiTheme.hbox(12)
	col.add_child(top)
	_product = CenterContainer.new()
	top.add_child(_product)
	var info := UiTheme.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	_name = Label.new()
	_name.theme_type_variation = UiTheme.LABEL_NOTE_TITLE
	info.add_child(_name)
	var need := Label.new()
	need.text = UiText.t("smithy.materials")
	info.add_child(need)
	_mats = HFlowContainer.new()
	_mats.add_theme_constant_override("h_separation", 10)
	_mats.add_theme_constant_override("v_separation", 4)
	info.add_child(_mats)
	var bottom := UiTheme.hbox(8)
	col.add_child(bottom)
	var wage := Label.new()
	wage.text = UiText.t("smithy.wage")
	bottom.add_child(wage)
	_wage = CoinLabel.make(0, 18)
	bottom.add_child(_wage)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap)
	forge_key = IconButton.make_art(KEY_DIR, KEY_ID, UiText.t("smithy.forge"), "", on_forge)
	if forge_key.theme_type_variation == UiTheme.BUTTON_ART:
		forge_key.art_label = UiText.t("smithy.forge")     # 图上不带字（中英文）
		forge_key.art_label_center = forge_key.custom_minimum_size * 0.5
		forge_key.art_label_size = 20
	else:
		forge_key.theme_type_variation = UiTheme.BUTTON_FORGE     # 没图：烧亮的铁红平键
		forge_key.custom_minimum_size = Vector2(110, 40)
	bottom.add_child(forge_key)


func _flat() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = NoticeScroll.PAPER_FALLBACK
	return s


## 换成这一张：产物、名字、每样素材有几 / 要几、工钱；[param why] 空 = 能打（打造键亮）
func show_recipe(r: SmithRecipeDef, items: ItemDatabase, got: Dictionary, why: String) -> void:
	UiTheme.clear_children(_product)
	var def := items.get_def(r.output)
	var size := def.shape.size_rotated(0) if def != null and def.shape != null else Vector2i.ONE
	var cell := floorf(minf(32.0, minf(72.0 / size.x, 72.0 / size.y)))
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


## 一样素材：小图 + 「有几 / 要几」（不够的铁红）
func _mat(d: ItemDef, have: int, need: int) -> Control:
	var row := UiTheme.hbox(4)
	row.tooltip_text = Names.of(d) if d != null else ""
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex := ItemPainter.art_of(d) if d != null else null
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(MAT_ICON, MAT_ICON)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		var swatch := ColorRect.new()
		swatch.color = ItemPainter.body_color(d) if d != null else Color.GRAY
		swatch.custom_minimum_size = Vector2(MAT_ICON, MAT_ICON) * 0.8
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
	var l := Label.new()
	l.text = "%d / %d" % [have, need]
	if have < need:
		l.add_theme_color_override("font_color", SHORT)
	row.add_child(l)
	return row


## 两头的轴（纸身之外，压在纸边上）
func _draw() -> void:
	var tex := UiTheme.art_cached(NoticeScroll.ROLLER)
	var h := size.y + 12.0
	for x in [0.0, size.x - NoticeScroll.ROLLER_W]:
		var r := Rect2(Vector2(x - NoticeScroll.ROLLER_OUT * (1.0 if x == 0.0 else -1.0), -6.0), Vector2(NoticeScroll.ROLLER_W, h))
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, NoticeScroll.ROLLER_FALLBACK)


## 测试看：现在写的产物名、素材那几行的字
func title() -> String:
	return _name.text


func material_lines() -> Array[String]:
	var out: Array[String] = []
	for row in _mats.get_children():
		out.append((row.get_child(row.get_child_count() - 1) as Label).text)
	return out


func wage() -> int:
	return _wage.amount
