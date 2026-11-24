## 报告 389 定稿：声望刻度上的一颗节点圆章（直径 40；通知里 64）。图标按种类用代码画（以后要正式小图再找美术）：
## 委托门槛 = 信封、开放 = 钥匙、提升 = 双上箭头、开放某位神 = 那位神的信仰徽记（`faith/<神>`）；留空 = 虚线圈加「?」。
## 到了：深底黄铜圈亮图标；没到：灰底灰圈灰图标，神的徽记 35% 不透明
class_name RepMedal
extends Control

const LIT_BG := Color("2e2a24")
const LIT_RING := Color("c9a04e")
const LIT_ICON := Color("ffd776")
const DIM_BG := Color("4a463e")
const DIM_RING := Color("6d6658")
const DIM_ICON := Color("9a927e")
const HID_RING := Color("8f866f")

var node: Dictionary = {}
var lit := false
## 同一个声望数上第几颗（0 = 最下面）
var stack := 0
## 外发光（通知里那颗）
var glow := false
var _god: Texture2D = null


static func make(n: Dictionary, p_lit: bool, _faith_defs: Dictionary = {}) -> RepMedal:
	var m := RepMedal.new()
	m.node = n
	m.lit = p_lit
	m.name = "Node_" + String(n.get("id", ""))
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.custom_minimum_size = Vector2(RepScale.MEDAL, RepScale.MEDAL)
	if icon_of(n) == "god":
		m._god = UiTheme.art_cached("faith/" + String(n.get("value", "")))
	return m


## 图标种类：hidden / god / letter（委托门槛）/ key（开放）/ up（提升）
static func icon_of(n: Dictionary) -> String:
	if Commissions.is_placeholder(n):
		return "hidden"
	var eff := String(n.get("effect", ""))
	if eff == "god":
		return "god"
	if eff == "inquiry" or eff == "finale":
		return "letter"
	return "up" if String(n.get("kind", "")) == String(Commissions.KIND_BOOST) else "key"


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	var kind := icon_of(node)
	if glow:
		for i in 4:
			draw_circle(c, r + 4.0 + float(i) * 3.0, Color(LIT_RING, 0.12))
	if kind == "hidden":
		draw_circle(c, r, Color(DIM_BG, 0.35))
		var seg := 16
		for i in seg:
			if i % 2 == 0:
				draw_arc(c, r - 1.0, TAU * float(i) / seg, TAU * float(i + 1) / seg, 4, HID_RING, 2.0)
		var font := get_theme_default_font()
		if font != null:
			var fs := int(r * 1.1)
			var qs := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, c + Vector2(-qs.x * 0.5, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, HID_RING)
		return
	draw_circle(c, r, LIT_BG if lit else DIM_BG)
	draw_arc(c, r - 1.0, 0.0, TAU, 40, LIT_RING if lit else DIM_RING, 2.0)
	var ink := LIT_ICON if lit else DIM_ICON
	var s := r * 0.5     # 图标半宽
	var w := maxf(1.5, r * 0.1)
	match kind:
		"god":
			if _god != null:
				var side := r * 1.5
				draw_texture_rect(_god, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, 1.0 if lit else 0.35))
		"letter":
			var box := Rect2(c + Vector2(-s, -s * 0.66), Vector2(2.0 * s, 1.33 * s))
			draw_rect(box, ink, false, w)
			draw_polyline(PackedVector2Array([box.position, c + Vector2(0, s * 0.1), Vector2(box.end.x, box.position.y)]), ink, w)
		"key":
			draw_arc(c + Vector2(-s * 0.45, 0), s * 0.42, 0.0, TAU, 20, ink, w)
			draw_line(c + Vector2(-s * 0.03, 0), c + Vector2(s, 0), ink, w)
			draw_line(c + Vector2(s * 0.55, 0), c + Vector2(s * 0.55, s * 0.32), ink, w)
			draw_line(c + Vector2(s * 0.95, 0), c + Vector2(s * 0.95, s * 0.32), ink, w)
		_:
			for dy in [-s * 0.4, s * 0.4]:
				draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, dy + s * 0.3), c + Vector2(0, dy - s * 0.3), c + Vector2(s * 0.7, dy + s * 0.3)]), ink, w)
