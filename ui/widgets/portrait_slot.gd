## 肖像位 / 徽记位（157 补充二，作者定：没图也先留框）：一块方位，**框永远在，图来了填进去**。
##
## 框是美术的 `portrait_frame.png`（中间透明的九宫格），画在位子外扩 json `inset` 处，不占排版；没这张图就画一圈细线。
## 214 定稿是铜币圆框：json 的边距、外扩都是 0，整张等比缩放盖在币缘上。
## 图都比位子大（源图 256，摆在 96 / 160 / 32），整块按 mipmap 缩小，币缘的细纹和刻线才不起锯齿（导入也要开 mipmap）
## 里面：有图放图；没图且是肖像位放 `portrait_empty.png`（暗底半身剪影），连这张也没有就自己画剪影；徽记位没图就空着
class_name PortraitSlot
extends Control

## 位子里那张图（肖像 / 徽记）；没图 null
var picture: TextureRect = null
## 没图时的占位（肖像位才有：美术的剪影图，或者 null = 自己画）
var placeholder: TextureRect = null
## 框（美术的框图；没图 null = 自己画细线）
var frame: NinePatchRect = null
var _silhouette := false


## [param side] 边长；[param face] 这个位子的图（null = 占位）；[param silhouette] 真 = 肖像位（没图画剪影），假 = 徽记位（没图空着）
func _init(side: int, face: Texture2D = null, silhouette: bool = true) -> void:
	custom_minimum_size = Vector2(side, side)
	# 作者 10-31 17:22「框和硬币为什么对不上」：位子在容器里被同排撑高 / 撑宽时，框（整张拉伸）成了椭圆、硬币（等比居中）还是正圆 —— 位子永远是正方，摆在格子正中
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS     # 子节点（图、占位、框）随它
	if face != null:
		picture = _fill(face)
	elif silhouette:
		var empty := UiTheme.art(UiTheme.ART_PORTRAIT_EMPTY)
		if empty != null:
			placeholder = _fill(empty)
		else:
			_silhouette = true
	var tex := UiTheme.art(UiTheme.ART_PORTRAIT_FRAME)
	if tex != null:
		var meta := UiTheme.art_meta(UiTheme.ART_PORTRAIT_FRAME)
		var m: Array = meta.get("margin", [4, 4, 4, 4])
		var inset := float(meta.get("inset", 4))
		frame = NinePatchRect.new()
		frame.texture = tex
		if m.size() == 4:
			frame.patch_margin_left = int(m[0])
			frame.patch_margin_top = int(m[1])
			frame.patch_margin_right = int(m[2])
			frame.patch_margin_bottom = int(m[3])
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.offset_left = -inset
		frame.offset_top = -inset
		frame.offset_right = inset
		frame.offset_bottom = inset
		add_child(frame)


func _fill(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	return r


## 没框图：暗底 + 一圈细线；没剪影图：半身剪影（头一个圆、肩一道弧）
func _draw() -> void:
	if frame == null or _silhouette:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiPalette.BG, 0.6))
	if _silhouette:
		var c := size * 0.5
		var r := size.x * 0.17
		draw_arc(c - Vector2(0, size.y * 0.1), r, 0.0, TAU, 32, UiPalette.LINE.lightened(0.3), 2.0)
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI + PI * float(i) / 16.0
			pts.append(Vector2(c.x + cos(a) * size.x * 0.32, size.y - 2.0 + sin(a) * size.y * 0.22))
		draw_polyline(pts, UiPalette.LINE.lightened(0.3), 2.0)
	if frame == null:
		draw_rect(Rect2(Vector2.ZERO, size), UiPalette.LINE.lightened(0.25), false, 2.0)
