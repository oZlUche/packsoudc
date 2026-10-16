## 179：选角色屏的图标牌 —— 图标 40 + 数字（28 粗体）+ 说明（13 灰），三块等宽横排（负重上限 / 棋盘 / 开局金币）。
## 图标先找 `assets/ui/setup/icons/<id>.png`（美术定稿，源图 80 按 40 显示，彩色成品不调色），没有退回 [member FALLBACK] 里那张（170 的提示框图标），
## 再没有就自己画一个占位（秤砣 / 格子 / 金币的轮廓）
class_name CapTile
extends PanelContainer

const ICON_DIR := "res://assets/ui/setup/icons/"
const ICON_PX := 40.0
const CAPTION_PX := 13
## 美术图没到时先借用的图
const FALLBACK := {&"weight": "res://assets/ui/tip/weight.png", &"coin": "res://assets/ui/tip/coin.png"}

var id: StringName = &""
var value_label: Label = null
var caption_label: Label = null
var icon: Control = null


func setup(p_id: StringName, value: String, caption: String) -> CapTile:
	id = p_id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_stretch_ratio = 1.0
	UiTheme.panel(self, -1, UiTheme.PANEL_CAP_TILE)     # 牌底：比凹槽板亮一档的暗底、细边
	var row := HBoxContainer.new()
	add_child(row)
	icon = _icon_for(p_id)
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	value_label = UiTheme.make_variant_label(value, UiTheme.LABEL_CAP_VALUE)
	col.add_child(value_label)
	caption_label = UiTheme.make_label(caption, CAPTION_PX, UiPalette.DIM)
	col.add_child(caption_label)
	return self


## 有没有用上美术图（测试看；占位画的是 false）
func has_art() -> bool:
	return icon is TextureRect


static func texture_for(p_id: StringName) -> Texture2D:
	for path in [ICON_DIR + String(p_id) + ".png", String(FALLBACK.get(p_id, ""))]:
		if path != "" and ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				return tex
	return null


func _icon_for(p_id: StringName) -> Control:
	var tex := texture_for(p_id)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return pic
	var drawn := Control.new()
	drawn.draw.connect(func(): _draw_placeholder(drawn, p_id))
	return drawn


## 没图时的占位轮廓
static func _draw_placeholder(c: Control, p_id: StringName) -> void:
	var r := Rect2(Vector2(4, 6), Vector2(ICON_PX - 8, ICON_PX - 12))
	match p_id:
		&"board":
			c.draw_rect(r, Color("2d3340"))
			var line := Color("8fa0bf")
			for i in 4:
				var x := r.position.x + r.size.x * float(i) / 4.0
				c.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), line, 1.0)
			for j in 3:
				var y := r.position.y + r.size.y * float(j) / 3.0
				c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), line, 1.0)
			c.draw_rect(r, line, false, 2.0)
		&"coin":
			c.draw_circle(Vector2(ICON_PX, ICON_PX) * 0.5, 14.0, Color("e6a83c"))
			c.draw_arc(Vector2(ICON_PX, ICON_PX) * 0.5, 9.0, 0.0, TAU, 32, Color("5a4522"), 1.5)
		_:
			var pts := PackedVector2Array([Vector2(20, 4), Vector2(30, 12), Vector2(26, 34), Vector2(14, 34), Vector2(10, 12)])
			c.draw_colored_polygon(pts, Color("8a7050"))
			c.draw_circle(Vector2(20, 6), 3.0, Color("c9a86a"))
