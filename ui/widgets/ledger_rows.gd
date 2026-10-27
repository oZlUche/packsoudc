## 226 §1.5 批三：小号账目行（借 224 账单的行样）—— 一行一笔：左边项目（宋体墨字）、右边数（粗体右对齐），行底一道淡墨线。
## 字由这里画（不是 Label），算在控件上；放在浅底（石板 / 纸）上。撤离确认框、科技的钱和材料在用
class_name LedgerRows
extends Control

const ROW_H := 34.0
const FONT_SIZE := 16
const PAD_X := 4.0
const INK_LABEL := Color("2e2219")
const INK_NUM := Color("16110d")
const LINE := Color(0.18, 0.13, 0.10, 0.35)

## 每行 {"label", "value", "color"}
var _rows: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## 加一行；[param color] 透明 = 墨色（付不起之类用红）
func add_row(label: String, value: String, color: Color = Color(0, 0, 0, 0)) -> void:
	_rows.append({"label": label, "value": value, "color": color})
	update_minimum_size()
	queue_redraw()


func rows() -> Array[Dictionary]:
	return _rows


func clear() -> void:
	_rows.clear()
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var fs := UiTheme.sz(FONT_SIZE)     # 258：按字号档
	var w := 0.0
	var f := UiPalette.cjk_font()
	var fb := UiPalette.cjk_font_bold()
	for r in _rows:
		w = maxf(w, f.get_string_size(String(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			+ fb.get_string_size(String(r["value"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 32.0 + 2.0 * PAD_X)
	return Vector2(w, ROW_H * _rows.size())


func _draw() -> void:
	var fs := UiTheme.sz(FONT_SIZE)     # 258：按字号档
	var f := UiPalette.cjk_font()
	var fb := UiPalette.cjk_font_bold()
	var base := (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var mid := ROW_H * (i + 0.5)
		var col: Color = r["color"]
		draw_string(f, Vector2(PAD_X, mid + base), String(r["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK_LABEL)
		var v := String(r["value"])
		var vw := fb.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(fb, Vector2(size.x - PAD_X - vw, mid + base), v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK_NUM if col.a == 0.0 else col)
		draw_line(Vector2(0.0, ROW_H * (i + 1) - 1.0), Vector2(size.x, ROW_H * (i + 1) - 1.0), LINE, 1.0)
