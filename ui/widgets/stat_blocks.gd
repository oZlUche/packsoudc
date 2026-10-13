## 161（作者定）：开局屏角色卡上的一排读数，用图形把角色之间的差别画显眼 ——
## 生命上限是红方块、耐力上限是黄方块，每块 [member unit] 点（作者定 10），最后一块按余数部分填充（45 和 55 一眼分得出）；
## 体力一点一颗心（和 HUD 同一颗，[method UiPalette.draw_heart]）。不写数字：方块就是读数，具体值在悬停提示里。
## 一排最多 [constant PER_ROW] 块，多了折行。只自绘，不加主题覆盖
class_name StatBlocks
extends Control

const HP := &"hp"
const STAMINA := &"stamina"
const VITALITY := &"vitality"

## 方块边长、块间距、圆角
const BLOCK := 22.0
const GAP := 4.0
const RADIUS := 5
const PER_ROW := 10

var kind: StringName = HP
var value: float = 0.0
var unit: float = 10.0


## 设好画什么（返回自己，方便链式加进容器）
func setup(p_kind: StringName, p_value: float, p_unit: float = 10.0) -> StatBlocks:
	kind = p_kind
	value = maxf(0.0, p_value)
	unit = maxf(1.0, p_unit)
	mouse_filter = Control.MOUSE_FILTER_STOP     # 停上去看具体值
	tooltip_text = text_of()
	custom_minimum_size = _extent()
	queue_redraw()
	return self


## 悬停提示与测试读的那一句
func text_of() -> String:
	match kind:
		VITALITY:
			return "体力 %d（一颗心一点）" % int(value)
		STAMINA:
			return "耐力上限 %d（一块 %d 点）" % [int(value), int(unit)]
	return "生命上限 %d（一块 %d 点）" % [int(value), int(unit)]


## 每块填了多少（0..1，最后一块可能不满）；心都是 1
func fills() -> Array[float]:
	var out: Array[float] = []
	if kind == VITALITY:
		for i in int(value):
			out.append(1.0)
		return out
	var full := int(floor(value / unit))
	for i in full:
		out.append(1.0)
	var rest := value - full * unit
	if rest > 0.001:
		out.append(rest / unit)
	return out


func color() -> Color:
	match kind:
		STAMINA:
			return UiPalette.STAMINA
	return UiPalette.HP


func _extent() -> Vector2:
	var n := fills().size()
	if n == 0:
		return Vector2(BLOCK, BLOCK)
	var cols := mini(n, PER_ROW)
	var rows := ceili(float(n) / PER_ROW)
	return Vector2(cols * BLOCK + (cols - 1) * GAP, rows * BLOCK + (rows - 1) * GAP)


func _draw() -> void:
	var list := fills()
	var col := color()
	for i in list.size():
		var at := Vector2(i % PER_ROW, floori(float(i) / PER_ROW)) * (BLOCK + GAP)
		if kind == VITALITY:
			UiPalette.draw_heart(self, at, BLOCK, UiPalette.HP)
			continue
		_block(Rect2(at, Vector2(BLOCK, BLOCK)), col, list[i])


## 一块卡通方块：暗槽 + 按比例填的亮块 + 上沿一道高光 + 一圈深边
func _block(r: Rect2, col: Color, fill: float) -> void:
	draw_style_box(_box(col.darkened(0.72), Color(0, 0, 0, 0), 0), r)
	if fill > 0.0:
		var f := Rect2(r.position, Vector2(maxf(RADIUS * 2.0, r.size.x * fill), r.size.y))
		draw_style_box(_box(col, Color(0, 0, 0, 0), 0), f)
		draw_style_box(_box(col.lightened(0.35), Color(0, 0, 0, 0), 0), Rect2(f.position + Vector2(3, 3), Vector2(f.size.x - 6, 4)))
	draw_style_box(_box(Color(0, 0, 0, 0), col.darkened(0.55), 2), r)


static func _box(bg: Color, edge: Color, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.draw_center = bg.a > 0.0
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_corner_radius_all(RADIUS)
	return b
