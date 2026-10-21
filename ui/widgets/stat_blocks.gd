## 161（作者定）：开局屏角色卡上的一排读数，用图形把角色之间的差别画显眼 ——
## 生命上限是红方块、耐力上限是黄方块，每块 [member unit] 点（作者定 10），最后一块按余数部分填充（45 和 55 一眼分得出）；
## 体力一点一颗心（和 HUD 同一颗，[method UiPalette.draw_heart]）。不写数字：方块就是读数，具体值在悬停提示里。
## 一排最多 [constant PER_ROW] 块，多了折行。只自绘，不加主题覆盖
class_name StatBlocks
extends Control

const HP := &"hp"
const STAMINA := &"stamina"
const VITALITY := &"vitality"

## 方块边长、块间距（心之间）、圆角。作者 2026-10-16：方块条要紧凑，格子之间不留空 —— 方块连成一根条，
## 只有整条两头是圆角，格与格之间一道细分隔线
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
			return UiText.t("strip.vitality_blocks") % int(value)
		STAMINA:
			return UiText.t("strip.stamina_blocks") % [int(value), int(unit)]
	return UiText.t("strip.hp_blocks") % [int(value), int(unit)]


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


## 横向的格距：方块条 0（连成一根），心照旧隔开
func gap_x() -> float:
	return GAP if kind == VITALITY else 0.0


func _extent() -> Vector2:
	var n := fills().size()
	if n == 0:
		return Vector2(BLOCK, BLOCK)
	var cols := mini(n, PER_ROW)
	var rows := ceili(float(n) / PER_ROW)
	return Vector2(cols * BLOCK + (cols - 1) * gap_x(), rows * BLOCK + (rows - 1) * GAP)


func _draw() -> void:
	var list := fills()
	var col := color()
	if kind == VITALITY:
		for i in list.size():
			UiPalette.draw_heart(self, Vector2(i % PER_ROW, floori(float(i) / PER_ROW)) * (BLOCK + GAP), BLOCK, UiPalette.HP)
		return
	var rows := ceili(float(list.size()) / PER_ROW)
	for row in rows:
		var first := row * PER_ROW
		var count := mini(PER_ROW, list.size() - first)
		var y := row * (BLOCK + GAP)
		var bar := Rect2(0, y, count * BLOCK, BLOCK)
		# 一整根：暗槽 → 各格按比例填亮 → 格间分隔线 → 整根一圈深边（只有两头圆角）
		draw_style_box(_box(col.darkened(0.72), Color(0, 0, 0, 0), 0, true, true), bar)
		for k in count:
			var fill: float = list[first + k]
			if fill <= 0.0:
				continue
			var f := Rect2(k * BLOCK, y, BLOCK * fill, BLOCK)
			draw_style_box(_box(col, Color(0, 0, 0, 0), 0, k == 0, k == count - 1 and fill >= 1.0), f)
			draw_rect(Rect2(f.position + Vector2(2 if k > 0 else 3, 3), Vector2(maxf(0.0, f.size.x - (4 if k > 0 else 5)), 4)), col.lightened(0.35))
		for k in range(1, count):
			draw_line(Vector2(k * BLOCK, y + 2), Vector2(k * BLOCK, y + BLOCK - 2), col.darkened(0.55), 1.0)
		draw_style_box(_box(Color(0, 0, 0, 0), col.darkened(0.55), 2, true, true), bar)


## [param left] / [param right]：那一头圆角（整根的两头），格与格相接处是直角
static func _box(bg: Color, edge: Color, width: int, left: bool, right: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.draw_center = bg.a > 0.0
	b.border_color = edge
	b.set_border_width_all(width)
	b.corner_radius_top_left = RADIUS if left else 0
	b.corner_radius_bottom_left = RADIUS if left else 0
	b.corner_radius_top_right = RADIUS if right else 0
	b.corner_radius_bottom_right = RADIUS if right else 0
	return b
