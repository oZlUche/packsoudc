## 166：读数旁边的一枚小图标（货币的金币、信仰的徽记）—— 有图贴图，没图按 [member fallback] 画个替身（金币：描边圆；空：什么都不画，只占位）
class_name HudIcon
extends Control

## 没图时画什么：&"coin" = 一枚描边的金色圆；&"" = 留空
var fallback: StringName = &""
var texture: Texture2D = null:
	set(v):
		texture = v
		queue_redraw()


static func make(px: float, p_fallback: StringName = &"") -> HudIcon:
	var i := HudIcon.new()
	i.custom_minimum_size = Vector2(px, px)
	i.fallback = p_fallback
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i


## 一张图（`res://` 路径）；没有返回 null
static func load_art(path: String) -> Texture2D:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return EventImage.load_texture(path)


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		return
	if fallback == &"coin":
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r - 1.0, Color("d9a93a"))
		draw_arc(size * 0.5, r - 1.0, 0.0, TAU, 24, Color("8a6418"), 1.5)
		draw_arc(size * 0.5, r * 0.55, 0.0, TAU, 20, Color("8a6418"), 1.0)
