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
## 233（作者 21:42 选乙）：商店是集市帐篷 —— 篷面九宫格（两侧垂布、木杆、油灯、地毯靠 expand_margin 画在窗外），
## 窗顶正中画尖顶、标题条上画布招牌（字写在红布上）；摆位全读 `shop/tent_front.json`（美术 `tent.json` 原样）
const TENT_ART := "shop/tent_front"
const TENT_PEAK := "shop/tent_peak"
const TENT_SIGN := "shop/tent_sign"
var tent := false
## 帐篷：内容区左右再让两侧垂布一点（美术说垂布最多伸进窗 22、边距 24 —— 截图上贴着布边，各多垫 12）
const TENT_SIDE_PAD := 12
## 帐篷：布招牌的流苏下沿以下再空这么多，内容才开始（标题条照美术在 14..50，字心对着红布中心 y 32）
const TENT_SIGN_CLEAR := 6

## 皮：石板（默认）/ 铜面板 / 书 / 帐篷；要的图缺了一律退回石板，[member skin] 记实际用上的那张
const SKIN_SLAB := &"slab"
const SKIN_BRONZE := &"bronze"
const SKIN_BOOK := &"book"
const SKIN_TENT := &"tent"
var skin: StringName = SKIN_SLAB


## [param margin] 是各屏原来给面板的内边距：平面底照旧当外框内边距；九宫格底时外框边距由图定，多出来的部分垫在内容区里。
## [param p_skin]：[constant SKIN_SLAB] / [constant SKIN_BRONZE] / [constant SKIN_BOOK]（232）/ [constant SKIN_TENT]（233）；缺图退回石板
func _init(margin: int = -1, p_skin: StringName = SKIN_SLAB) -> void:
	book = p_skin == SKIN_BOOK and UiTheme.art_cached(BOOK_ART) != null
	if book:
		skin = SKIN_BOOK
		_init_book()
		return
	bronze = p_skin == SKIN_BRONZE and UiTheme.art(BRONZE_ART) != null
	if bronze:
		skin = SKIN_BRONZE
		_init_bronze(margin)
		return
	tent = p_skin == SKIN_TENT and UiTheme.art_cached(TENT_ART) != null
	var box: StyleBox
	if tent:
		skin = SKIN_TENT
		box = _tent_box()
		add_theme_stylebox_override("panel", box)
		UiTheme.set_tone(self, StringName(String(UiTheme.art_meta(TENT_ART).get("tone", "light"))))
	else:
		UiTheme.slab(self)     # 157 补充三：一整块石板；深底浅字、浅底墨字
		box = UiTheme.current().get_stylebox("panel", UiTheme.PANEL_OVERLAY)
	var textured := UiTheme.is_art_box(box) or tent
	var want := margin if margin >= 0 else UiTheme.PANEL_MARGIN
	var col := UiTheme.vbox(GAP)
	add_child(col)
	var head := MarginContainer.new()
	title_bar = UiTheme.hbox(8)
	title_bar.custom_minimum_size.y = UiTheme.frame_title_height()
	head.add_child(title_bar)
	col.add_child(head)
	title_label = UiTheme.make_label("")
	title_label.theme_type_variation = UiTheme.LABEL_TENT_SIGN if tent else UiTheme.LABEL_OVERLAY_TITLE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tent:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER     # 字落在窗正中的布招牌上
		title_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		title_label.custom_minimum_size.y = TENT_TITLE_H
		title_bar.custom_minimum_size.y = tent_title_bar_height(box)
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
		var side := pad + (TENT_SIDE_PAD if tent else 0)
		UiTheme.margins(content, side, 0, side, pad)
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


## 233：帐篷篷面（`tent_front.json` 的 front：三组 margin 都是左上右下）
static func _tent_box() -> StyleBoxTexture:
	var front: Dictionary = tent_meta().get("front", {})
	var tm: Array = front.get("texture_margin", [126, 94, 126, 80])
	var em: Array = front.get("expand_margin", [92, 30, 92, 40])
	var cm: Array = front.get("content_margin", [24, 14, 24, 30])
	var box := StyleBoxTexture.new()
	box.texture = UiTheme.art_cached(TENT_ART)
	var sides := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	for i in 4:
		box.set_texture_margin(sides[i], float(tm[i]))
		box.set_expand_margin(sides[i], float(em[i]))
		box.set_content_margin(sides[i], float(cm[i]))
	return box


## 233：帐篷的摆位（美术 `tent.json` 原样：front / peak / sign）
static func tent_meta() -> Dictionary:
	return UiTheme.art_meta(TENT_ART)


## 233：标题字那一行的高（美术：标题条在内容区最上面 14..50，字心 = 红布中心 y 32）
const TENT_TITLE_H := 36


## 233：标题条整条的高 —— 布招牌连流苏挂到窗顶下 `sign 左上 y + 图高`（70），内容要从那下面 [constant TENT_SIGN_CLEAR] 开始
func tent_title_bar_height(box: StyleBox) -> float:
	var tex := UiTheme.art_cached(TENT_SIGN)
	var h := tex.get_size().y if tex != null else 74.0
	var bottom := tent_sign_at().y + h + TENT_SIGN_CLEAR
	return maxf(TENT_TITLE_H, bottom - box.content_margin_top - GAP)


## 233：尖顶左上（窗坐标；x 跟着窗宽居中）
func tent_peak_at() -> Vector2:
	var tex := UiTheme.art_cached(TENT_PEAK)
	var w := tex.get_size().x if tex != null else 420.0
	var y := float((tent_meta().get("peak", {}) as Dictionary).get("top_left_rel_panel", [0, -56])[1])
	return Vector2(roundf((size.x - w) * 0.5), y)


## 233：布招牌左上（窗坐标）
func tent_sign_at() -> Vector2:
	var tex := UiTheme.art_cached(TENT_SIGN)
	var w := tex.get_size().x if tex != null else 276.0
	var y := float((tent_meta().get("sign", {}) as Dictionary).get("top_left_rel_panel", [0, -4])[1])
	return Vector2(roundf((size.x - w) * 0.5), y)


## 这张皮在窗顶上面还要占多高（帐篷的尖顶；别的皮 0）—— [method GameScreen._centered_panel] 拿它给顶端栏让位
func outset_top() -> float:
	return -tent_peak_at().y if tent else 0.0


func _draw() -> void:
	if not tent:
		return
	var peak := UiTheme.art_cached(TENT_PEAK)     # 在篷面上、标题字下（子节点画在 _draw 之后）
	if peak != null:
		draw_texture(peak, tent_peak_at())
	var sign_tex := UiTheme.art_cached(TENT_SIGN)
	if sign_tex != null:
		draw_texture(sign_tex, tent_sign_at())


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
