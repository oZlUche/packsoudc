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


## [param margin] 是各屏原来给面板的内边距：平面底照旧当外框内边距；九宫格底时外框边距由图定，多出来的部分垫在内容区里
func _init(margin: int = -1) -> void:
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


func set_title(text: String) -> Label:
	title_label.text = text
	return title_label


func title() -> String:
	return title_label.text


## 往标题条右边放一个控件（按钮）
func add_slot(c: Control) -> void:
	slots.add_child(c)
