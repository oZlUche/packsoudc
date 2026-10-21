## 铜面板三屏（UI替换美术 bronze3 `frames_dark`，作者 2026-10-21 16:15）：棋盘外面套一层外框 ——
## `assets/ui/bronze/frame_<kind>_dark.png` 九宫（四边平铺），框里的内垫是深色半透明（铜面板透出来）；
## 格子缩进 = 切图的 `cells_offset`。没图 = 空框只留边距。格缝照 [method dark_seams]
class_name BoardFrame
extends PanelContainer

const DIR := "res://assets/ui/bronze/"
const LAYOUT := "bronze/layout"


## 把 [param view] 套进一个 [param kind] 外框：原来在哪个父节点、第几个，框就放在那儿
static func around(view: Control, kind: String) -> BoardFrame:
	var f := BoardFrame.new()
	f.name = "BoardFrame"
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	f.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	f.add_theme_stylebox_override("panel", box(kind))
	UiTheme.set_tone(f, UiTheme.TONE_DARK)
	var parent := view.get_parent()
	if parent != null:
		var at := view.get_index()
		parent.remove_child(view)
		parent.add_child(f)
		parent.move_child(f, at)
	f.add_child(view)
	if view is InventoryView:
		(view as InventoryView).seams = dark_seams()
	return f


static func box(kind: String) -> StyleBox:
	var piece: Dictionary = (layout().get("frames_dark", {}) as Dictionary).get(kind, {})
	var path := DIR + String(piece.get("file", "frame_%s_dark.png" % kind))
	var tex := EventImage.load_texture(path) if ResourceLoader.exists(path) else null
	var out: StyleBox
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.set_texture_margin_all(float(piece.get("margin", 70)))
		sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		out = sbt
	else:
		out = StyleBoxEmpty.new()
	out.set_content_margin_all(float(piece.get("cells_offset", 40)))
	return out


## 铜面板三屏的排版（UI替换美术 bronze3 `layout.json`）
static func layout() -> Dictionary:
	return UiTheme.art_meta(LAYOUT)


## 深色内垫上的格缝（黑缝 40%、亮线 30%，两端缩 3）—— [member InventoryView.seams] 认的键
static func dark_seams() -> Dictionary:
	return ((layout().get("boards_dark", {}) as Dictionary).get("cell_seams", {}) as Dictionary).duplicate()
