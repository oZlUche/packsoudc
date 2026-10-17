## 182（作者 2026-10-17 15:26）：说明「某一类节点」的一张纸签，弹在屏幕正中 —— 开局第三页点出生点时用；
## 将来地图屏头一回遇到新类型的节点也能用它（084 节点浮窗的居中版）。
## 第一行字记 + 类型名，第二行这一类节点的一句说明，可选的第三行（路线），底下一行小字。
## 只管显示；什么时候开、什么时候关由用它的屏决定（[method show_for] / [method close]）
class_name NodeHintCard
extends PanelContainer

const WIDTH := 420.0
const GLYPH_SIZE := 30
const NAME_SIZE := 22
const BODY_SIZE := 17
const FOOT_SIZE := 13
## 弹出 / 收起多快
const FADE_SEC := 0.15

## 现在说的是哪个节点（-1 = 关着）
var node_id: int = -1
var type: StringName = &""
var _glyph: Label = null
var _name: Label = null
var _body: RichTextLabel = null
var _extra: RichTextLabel = null
var _foot: Label = null
var _tween: Tween = null


func _init() -> void:
	name = "NodeHintCard"
	theme_type_variation = UiTheme.PANEL_NODE_HINT
	UiTheme.set_tone(self, UiTheme.tone_of(UiTheme.PANEL_NODE_HINT))
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
	# 屏幕正中：锚在中间，按内容往四周长
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	resized.connect(_recenter)
	var col := UiTheme.vbox(8)
	add_child(col)
	var head := UiTheme.hbox(10)
	col.add_child(head)
	_glyph = UiTheme.make_label("", GLYPH_SIZE, UiTheme.PARCHMENT_RED)
	head.add_child(_glyph)
	_name = UiTheme.make_label("", NAME_SIZE)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_name)
	_body = UiTheme.rich_block(WIDTH - 60.0, BODY_SIZE)
	col.add_child(_body)
	_extra = UiTheme.rich_block(WIDTH - 60.0, FOOT_SIZE + 2)
	col.add_child(_extra)
	_foot = UiTheme.make_label("", FOOT_SIZE, UiPalette.DIM)
	col.add_child(_foot)
	for c in [_glyph, _name, _body, _extra, _foot]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## 说明节点 [param id]（类型 [param p_type]）：[param hint] 是说明句（BBCode），[param extra] 第三行（空 = 不要这一行），[param foot] 底下的小字
func show_for(id: int, p_type: StringName, hint: String, extra: String = "", foot: String = "", animate: bool = true) -> void:
	node_id = id
	type = p_type
	var style := MapNodeStyle.of(p_type)
	_glyph.text = String(style.get("glyph", ""))
	_name.text = NodeText.label_of(p_type)
	UiTheme.set_rich(_body, hint)
	UiTheme.set_rich(_extra, extra)
	_extra.visible = extra != ""
	_foot.text = foot
	_foot.visible = foot != ""
	visible = true
	reset_size()
	_recenter()
	_fade(1.0, animate)


## 中心对准锚点（屏幕正中）：内容长短不一，量好自己多大再摆
func _recenter() -> void:
	var half := (size * 0.5).round()
	offset_left = -half.x
	offset_top = -half.y
	offset_right = offset_left + size.x
	offset_bottom = offset_top + size.y


func close(animate: bool = true) -> void:
	if node_id < 0 and not visible:
		return
	node_id = -1
	_fade(0.0, animate)


func is_open() -> bool:
	return node_id >= 0


func _fade(to: float, animate: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if not animate or not is_inside_tree():
		modulate.a = to
		visible = to > 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", to, FADE_SEC)
	if to <= 0.0:
		_tween.tween_callback(func(): visible = false)


## 这一类节点的说明句：本章的浮窗文字（`ChapterDef.tooltip_texts`，按 [NodeTooltip] 的类别）写了就用，没有用 [constant MapNodeTypes.HINTS]
static func hint_for(chapter: ChapterDef, p_type: StringName) -> String:
	if chapter != null and chapter.tooltip_texts.has(String(p_type)):
		return TextTemplate.render(String(chapter.tooltip_texts[String(p_type)]), {})
	return String(MapNodeTypes.HINTS.get(p_type, NodeText.label_of(p_type)))
