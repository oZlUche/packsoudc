## 报告 389 第七节：键右上角的红点 —— 一份是直径 16 的红点；多于一份换成高 24、写份数的红签；0 不显示。
## [method attach] 挂到键上（同一个键再调就改数），贴右上角、压出边一点
class_name RedDot
extends Control

const RED := Color("d8352a")
const DOT := 16.0
const TAG_H := 24.0

var count := 0


static func attach(host: Control, n: int) -> RedDot:
	var d := host.get_node_or_null("RedDot") as RedDot
	if d == null:
		d = RedDot.new()
		d.name = "RedDot"
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.z_index = 2
		host.add_child(d)
		host.resized.connect(d._place)
	d.count = n
	d.visible = n > 0
	d._place()
	return d


func _place() -> void:
	var host := get_parent() as Control
	if host == null:
		return
	var sz := Vector2(DOT, DOT) if count <= 1 else Vector2(maxf(TAG_H, 12.0 + 9.0 * float(str(count).length())), TAG_H)
	size = sz
	position = Vector2(host.size.x - sz.x * 0.6, -sz.y * 0.4)
	queue_redraw()


func _draw() -> void:
	if count <= 0:
		return
	if count == 1:
		draw_circle(size * 0.5, DOT * 0.5, RED)
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = RED
	sb.set_corner_radius_all(int(TAG_H * 0.5))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	if font != null:
		var txt := str(count)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, Vector2((size.x - w.x) * 0.5, size.y * 0.5 + 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
