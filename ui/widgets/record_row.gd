## 261：对局记录的一行 —— 一块能点的石账行（226 那种行样：浅底墨字、行底一道淡墨线），几栏按比例排开，结局那栏撤离绿 / 战败红；
## 字由这里画（不是 Label），一栏放不下就缩字
class_name RecordRow
extends Button

const FONT_SIZE := 15
const MIN_SIZE := 10
const PAD_X := 10.0
## 各栏占的宽度比例（第几局 · 时间 · 章节 · 角色 · 结局 · 值 · 步数）
const WEIGHTS := [0.09, 0.11, 0.24, 0.12, 0.17, 0.17, 0.10]
const OUTCOME_COL := 4
const INK := Color("2e2219")
const LINE := Color(0.18, 0.13, 0.10, 0.35)
const HOVER := Color(1, 1, 1, 0.18)

var columns: Array = []
var outcome_color := INK


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_columns: Array, p_outcome_color: Color) -> void:
	columns = p_columns
	outcome_color = p_outcome_color
	queue_redraw()


## 第 [param i] 栏在本行里的矩形
func column_rect(i: int) -> Rect2:
	var x := 0.0
	for k in i:
		x += size.x * float(WEIGHTS[k])
	return Rect2(Vector2(x, 0), Vector2(size.x * float(WEIGHTS[i]), size.y))


## 第 [param i] 栏的字用几号（放不下就缩）
func column_size(i: int) -> int:
	return RecordsStele.fit_size(UiPalette.cjk_font(), String(columns[i]), UiTheme.sz(FONT_SIZE), column_rect(i).size.x - 2.0 * PAD_X)


func _draw() -> void:
	if is_hovered():
		draw_rect(Rect2(Vector2.ZERO, size), HOVER)
	var f := UiPalette.cjk_font()
	for i in mini(columns.size(), WEIGHTS.size()):
		var r := column_rect(i)
		var fs := column_size(i)
		var y := size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		draw_string(f, Vector2(r.position.x + PAD_X, y), String(columns[i]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2.0 * PAD_X, fs, outcome_color if i == OUTCOME_COL else INK)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), LINE, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_RESIZED:
		queue_redraw()
