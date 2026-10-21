## 叠层共用的石板框（157）：顶上一条**标题条**（左标题、右一排槽放各屏自己的收起 / 关闭 / 返回）+ 下面的**内容区**。
##
## [method GameScreen._centered_panel] 造它、把 [member content] 交给各屏 —— 各屏照旧往里加一个子节点，标题写进 [method set_title]。
## 外观是主题变体 [constant UiTheme.PANEL_OVERLAY]：157 补充三起是**一整块石板**（[SlabStyle]：板身平铺 + 板边九宫格，
## 标题字刻在板顶那道刻线上方，高度读 `slab_edge.json` 的 `title_height`），没图就是原来那块平面底。
class_name OverlayFrame
extends PanelContainer

## 标题条与内容区之间（石板框：标题条下沿到内容区上沿至少要过图上那道线）
const GAP := 8

var title_bar: HBoxContainer
var title_label: Label
## 标题条右边的槽：各屏把自己的按钮放进来
var slots: HBoxContainer
## 各屏的东西放这里
var content: MarginContainer
## 铜面板三屏（战前准备 / 战斗 / 战利品）用 [constant BRONZE_ART]，不是石板
var bronze := false

## 铜面板（UI替换美术 甲 铜战板，作者 2026-10-21 16:07）：九宫边 83、边段 TILE_FIT（铆钉每 70 一颗），内容从 [constant BRONZE_INSET] 起；
## 没有标题条（作者 16:01 去掉顶上的空白条）；铜面偏深 = 深底浅字
const BRONZE_ART := "bronze/panel_bronze"
const BRONZE_MARGIN := 83
const BRONZE_INSET := 40
## 232（作者 19:23 选 1）：事件屏是一本摊开的书 —— 一整张图（`event/event_book`）不拉伸，图左上 = 框左上 − `panel_at`；
## 没有标题条，标题标签（[member title_label]）由事件屏摆进右页；书页浅底墨字
const BOOK_ART := "event/event_book"
const BOOK_TITLE_SIZE := 26
var book := false
## 书那张图（测试看位置）
var book_back: TextureRect = null


## [param margin] 是各屏原来给面板的内边距：平面底照旧当外框内边距；九宫格底时外框边距由图定，多出来的部分垫在内容区里。
## [param p_bronze]：铜面板（没图退回石板）
## [param p_book]：书（232；没图退回石板）
func _init(margin: int = -1, p_bronze: bool = false, p_book: bool = false) -> void:
	book = p_book and UiTheme.art_cached(BOOK_ART) != null
	if book:
		_init_book()
		return
	bronze = p_bronze and UiTheme.art(BRONZE_ART) != null
	if bronze:
		_init_bronze(margin)
		return
	UiTheme.slab(self)     # 157 补充三：一整块石板；深底浅字、浅底墨字
	var box := UiTheme.current().get_stylebox("panel", UiTheme.PANEL_OVERLAY)
	var textured := UiTheme.is_art_box(box)
	var want := margin if margin >= 0 else UiTheme.PANEL_MARGIN
	var col := UiTheme.vbox(GAP)
	add_child(col)
	var head := MarginContainer.new()
	title_bar = UiTheme.hbox(8)
	title_bar.custom_minimum_size.y = UiTheme.frame_title_height()
	head.add_child(title_bar)
	col.add_child(head)
	title_label = UiTheme.make_label("")
	title_label.theme_type_variation = UiTheme.LABEL_OVERLAY_TITLE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_bar.add_child(title_label)
	slots = UiTheme.hbox(8)
	title_bar.add_child(slots)
	content = MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(content)
	if textured:
		# 九宫格：外框边距是图上的边；各屏要的内边距比图边宽的那部分垫进内容区
		var pad := maxi(0, want - int(box.content_margin_left))
		UiTheme.margins(content, pad, 0, pad, pad)
		UiTheme.margins(head, 0, 0, 0, 0)
	else:
		UiTheme.panel(self, want, UiTheme.PANEL_OVERLAY)
		UiTheme.margins(content, 0, 0, 0, 0)
		# 内边距很小的框（事件屏：左栏的图铺到边）—— 标题条自己垫一点，字不贴边
		var head_pad := maxi(0, UiTheme.PANEL_MARGIN - want)
		UiTheme.margins(head, head_pad, head_pad, head_pad, 0)


func _init_bronze(margin: int) -> void:
	var box := StyleBoxTexture.new()
	box.texture = UiTheme.art(BRONZE_ART)
	box.set_texture_margin_all(BRONZE_MARGIN)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.set_content_margin_all(BRONZE_INSET)
	add_theme_stylebox_override("panel", box)
	UiTheme.set_tone(self, UiTheme.TONE_DARK)
	var col := UiTheme.vbox(0)
	add_child(col)
	title_bar = UiTheme.hbox(8)     # 没有标题条：留着空的，[method set_title] 照旧能调（字不显示）
	title_bar.visible = false
	col.add_child(title_bar)
	title_label = UiTheme.make_label("")
	title_bar.add_child(title_label)
	slots = UiTheme.hbox(8)
	title_bar.add_child(slots)
	content = MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := maxi(0, margin - BRONZE_INSET) if margin >= 0 else 0
	UiTheme.margins(content, pad, pad, pad, pad)
	col.add_child(content)


func _init_book() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	UiTheme.set_tone(self, UiTheme.TONE_LIGHT)
	var meta := book_meta()
	var back := Control.new()     # 框把它铺满；图在它里面往左上出 panel_at
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	book_back = TextureRect.new()
	book_back.name = "Book"
	book_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_back.texture = UiTheme.art_cached(BOOK_ART)
	var at: Array = meta.get("panel_at", [40, 34])
	book_back.position = -Vector2(float(at[0]), float(at[1]))
	book_back.size = book_back.texture.get_size()
	back.add_child(book_back)
	title_bar = UiTheme.hbox(8)     # 没有标题条：留着空的
	title_bar.visible = false
	back.add_child(title_bar)
	slots = UiTheme.hbox(8)
	title_bar.add_child(slots)
	title_label = UiTheme.make_label("", BOOK_TITLE_SIZE)
	title_label.theme_type_variation = UiTheme.LABEL_OVERLAY_TITLE
	title_label.add_theme_font_size_override("font_size", BOOK_TITLE_SIZE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content = MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiTheme.margins(content, 0, 0, 0, 0)
	add_child(content)


## 书的摆位（`event_book.json`：panel_at、image_rect、text_rect、title_h，面板坐标）
static func book_meta() -> Dictionary:
	return UiTheme.art_meta(BOOK_ART)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and title_label != null and is_instance_valid(title_label) and title_label.get_parent() == null:
		title_label.free()     # 书：标题标签没被摆进右页时自己收


func set_title(text: String) -> Label:
	title_label.text = text
	return title_label


func title() -> String:
	return title_label.text


## 往标题条右边放一个控件（按钮）
func add_slot(c: Control) -> void:
	slots.add_child(c)
