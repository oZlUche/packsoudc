## 报告 389（作者 11-24 15:43 定稿 A，规格 `art/ui/s389-rep/规格.md`）：一方阵营的声望刻度 —— 0–100 等比（各方同一把尺），
## 深色槽、黄铜填充、填充头一根亮线；每 10 一根刻度线（50 的倍数长一点），槽下只写 0 / 50 / 100。
## 节点是槽上方的圆章（[RepMedal]），圆心对准它的声望数；同一个数上的几个往上叠，最下面一个用细竖线接到槽。
## 声望过了 100：填满，数照写（在牌头）
class_name RepScale
extends Control

const SCALE := 100
const GROOVE_H := 12.0
const FILL_H := 8.0
const MEDAL := 40.0
const STACK_GAP := 4.0
## 槽中线离底多远（下面留刻度和数字）
const BELOW := 34.0
const GROOVE := Color("17140f")
const FILL_TOP := Color("e6c77a")
const FILL_MID := Color("c9a04e")
const FILL_LOW := Color("9b7630")
const HEAD := Color("ffe39a")
const TICK := Color("6d6658")
const TICK_TEXT := Color("8f866f")
const POST := Color("6d6658")

var book: CommissionBook = null
var faction: FactionDef = null
var faith_defs: Dictionary = {}
var _medals: Array[RepMedal] = []


static func make(p_book: CommissionBook, f: FactionDef, p_faith_defs: Dictionary = {}) -> RepScale:
	var s := RepScale.new()
	s.name = "RepScale"
	s.book = p_book
	s.faction = f
	s.faith_defs = p_faith_defs
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.custom_minimum_size = Vector2(240, BELOW + MEDAL + 14.0 + (MEDAL + STACK_GAP) * float(maxi(0, s._max_stack() - 1)))
	s._build()
	s.resized.connect(s._place)
	return s


func rep() -> int:
	return book.rep_of(faction.id) if book != null and faction != null else 0


## 声望数 → 槽上的 x
func x_of(v: int) -> float:
	var pad := MEDAL * 0.5
	return pad + (size.x - 2.0 * pad) * clampf(float(v) / float(SCALE), 0.0, 1.0)


func groove_y() -> float:
	return size.y - BELOW


func medals() -> Array[RepMedal]:
	return _medals


func _max_stack() -> int:
	var at := {}
	var top := 1
	for n in Commissions.nodes_of(faction):
		var k := int(n.get("rep", 0))
		at[k] = int(at.get(k, 0)) + 1
		top = maxi(top, int(at[k]))
	return top


func _build() -> void:
	var at := {}
	for n in Commissions.nodes_of(faction):
		var k := int(n.get("rep", 0))
		var m := RepMedal.make(n, Commissions.reached(book, faction, n), faith_defs)
		m.stack = int(at.get(k, 0))
		at[k] = m.stack + 1
		m.tooltip_text = medal_tip(n)
		_medals.append(m)
		add_child(m)


## 悬停：「声望数 · 种类」/ 效果（留空的不写）/ 已到 或 还差 N 点
func medal_tip(n: Dictionary) -> String:
	var k := int(n.get("rep", 0))
	var lines: PackedStringArray = []
	if Commissions.is_placeholder(n):
		lines.append("%d · %s" % [k, UiText.t("node.unknown")])
	else:
		lines.append("%d · %s" % [k, UiText.t("node.kind_" + RepMedal.icon_of(n))])
		lines.append(Commissions.node_text(n, faith_defs, book, faction))
	lines.append(UiText.t("node.reached") if rep() >= k and not Commissions.is_placeholder(n) else UiText.t("node.need") % maxi(0, k - rep()))
	return "\n".join(lines)


func _place() -> void:
	var gy := groove_y()
	for m in _medals:
		var v := int(m.node.get("rep", 0))
		m.position = Vector2(x_of(v) - MEDAL * 0.5, gy - GROOVE_H * 0.5 - 6.0 - MEDAL - float(m.stack) * (MEDAL + STACK_GAP))
		m.size = Vector2(MEDAL, MEDAL)
	queue_redraw()


func _draw() -> void:
	var gy := groove_y()
	var x0 := x_of(0)
	var x1 := x_of(SCALE)
	var font := get_theme_default_font()
	for m in _medals:     # 竖线：最下面那颗接到槽
		if m.stack == 0:
			var x := x_of(int(m.node.get("rep", 0)))
			draw_line(Vector2(x, m.position.y + MEDAL), Vector2(x, gy - GROOVE_H * 0.5), POST, 2.0)
	_round_rect(Rect2(x0 - 4.0, gy - GROOVE_H * 0.5, x1 - x0 + 8.0, GROOVE_H), GROOVE)
	var fx := x_of(rep())
	if fx > x0:
		var top := Rect2(x0 - 2.0, gy - FILL_H * 0.5, fx - x0 + 2.0, FILL_H / 3.0)
		_round_rect(Rect2(x0 - 2.0, gy - FILL_H * 0.5, fx - x0 + 2.0, FILL_H), FILL_MID)
		draw_rect(top, FILL_TOP)
		draw_rect(Rect2(x0 - 2.0, gy + FILL_H / 6.0, fx - x0 + 2.0, FILL_H / 3.0), FILL_LOW)
	draw_rect(Rect2(fx - 1.5, gy - 9.0, 3.0, 18.0), HEAD)
	for v in range(0, SCALE + 1, 10):
		var x := x_of(v)
		draw_line(Vector2(x, gy + 7.0), Vector2(x, gy + 7.0 + (6.0 if v % 50 == 0 else 4.0)), TICK, 1.0)
	if font != null:
		for v in [0, 50, 100]:
			var txt := str(v)
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(font, Vector2(x_of(v) - w * 0.5, gy + 28.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TICK_TEXT)


func _round_rect(r: Rect2, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(sb, r)
