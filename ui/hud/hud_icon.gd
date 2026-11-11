## 166：读数旁边的一枚小图标（货币的金币、信仰的徽记）—— 有图贴图，没图什么都不画，只占位
class_name HudIcon
extends Control

var texture: Texture2D = null:
	set(v):
		texture = v
		queue_redraw()


static func make(px: float) -> HudIcon:
	var i := HudIcon.new()
	i.custom_minimum_size = Vector2(px, px)
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
