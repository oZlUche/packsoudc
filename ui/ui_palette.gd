## 界面共用的配色与字体。
##
## 抽出来是因为两个沙盒各自复制过一份 —— 复制出来的第二份迟早跟第一份长得不一样。
class_name UiPalette
extends RefCounted

## 原来的底色（最深的那档）；运行时的底色走 [method bg]
const BG := Color("101216")
## 091（作者定）：背景底色可选，默认比原来浅一点。设置屏挑，存在 [GameSettings.bg_theme]
const BG_THEMES := [
	{"id": "graphite", "name": "石墨（默认）", "color": Color("262b33")},
	{"id": "dark", "name": "深夜（原来的）", "color": Color("101216")},
	{"id": "slate", "name": "石板", "color": Color("1b2028")},
	{"id": "dusk", "name": "暮色", "color": Color("2a2733")},
	{"id": "moss", "name": "苔绿", "color": Color("1f2a24")},
	{"id": "mist", "name": "雾灰（最浅）", "color": Color("3a3f48")},
]
const BG_DEFAULT := "graphite"
static var bg_theme: String = BG_DEFAULT
const PANEL := Color("171a20")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")
const LINE := Color("2a2f38")

const HP := Color("d9534f")
const SHIELD := Color("5bc0de")
## 106（作者定）：护盾不再是独立的一条，而是生命条外侧的一圈粗白框 —— 这是那圈框的颜色
const SHIELD_FRAME := Color("f2f6ff")
const STAMINA := Color("f0ad4e")
const MANA := Color("7a8cf0")
const HEAL := Color("5cb85c")
## 104：暴击的飘字
const CRIT := Color("ffd23f")

## 邻接标记的两个方向。**按语义分色，不是按形状** ——
## 参照作品用星形／菱形区分，那只是两个任意符号；这里直接用颜色 + 文字。
const GRANT := Color("6fb3f0")    ## 增益：我给站在这儿的邻居加成
const RECEIVE := Color("f0a85c")  ## 受益：站在这儿的邻居给我加成

## 资源键 → 条的颜色。未登记的资源用 DIM，不至于看不见。
const RESOURCE_COLORS := {
	"hp": HP,
	"shield": SHIELD,
	"stamina": STAMINA,
	"mana": MANA,
}

## 伤害类型 → 数字的颜色
const DAMAGE_COLORS := {
	"physical": Color("ff8a7a"),
	"fire": Color("ff9d4d"),
	"poison": Color("8ed36b"),
	"bleed": Color("e05c7a"),
	"reflect": Color("c9a0ff"),
	"drain": Color("9aa3b2"),
}


static func resource_color(key: StringName) -> Color:
	return RESOURCE_COLORS.get(String(key), DIM)


#region 样式码的颜色（101 第 5 刀）
## 文本层样式码（`{c:hp}`，见 [TextTemplate.STYLE_NAMES]）的颜色名 → 颜色。
##
## 表在这边是因为颜色是界面的事：[TextTemplate] 只产出带名字的 `[color=@hp]`，
## 画之前由 [method resolve_styles] 换成十六进制。名字对不上的原样留着（一眼看得见，也不会崩）
const STYLE_COLORS := {
	"fg": FG, "dim": DIM, "hp": HP, "shield": SHIELD,
	"stamina": STAMINA, "mana": MANA, "heal": HEAL,
	"grant": GRANT, "receive": RECEIVE,
	"warn": STAMINA, "danger": HP, "good": HEAL,
}


## 把 BBCode 里的 `[color=@名字]` 换成真颜色。给 RichTextLabel 之前调（[TextTemplate.render] 的输出都要过这一道）
static func resolve_styles(bbcode: String) -> String:
	if not bbcode.contains("[color=" + TextTemplate.STYLE_PREFIX):
		return bbcode
	var out := bbcode
	for name in STYLE_COLORS:
		out = out.replace("[color=%s%s]" % [TextTemplate.STYLE_PREFIX, name],
			"[color=#%s]" % (STYLE_COLORS[name] as Color).to_html(false))
	# 112：`{item:id}` 的名字按稀有度上色（和道具悬浮窗里的名字同色）
	for r in ItemPainter.RARITY_COLORS.size():
		out = out.replace("[color=%s%s%d]" % [TextTemplate.STYLE_PREFIX, TextTemplate.RARITY_STYLE, r],
			"[color=#%s]" % (ItemPainter.RARITY_COLORS[r] as Color).to_html(false))
	return out
#endregion


static func damage_color(type: StringName) -> Color:
	return DAMAGE_COLORS.get(String(type), FG)


## Godot 内置字体不含 CJK 字形，中文会显示成方块
static func cjk_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(
		["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"]
	)
	return f


#region 背景底色（091）
static func bg() -> Color:
	for t in BG_THEMES:
		if String(t["id"]) == bg_theme:
			return t["color"]
	return BG_THEMES[0]["color"]


static func has_bg_theme(id: String) -> bool:
	for t in BG_THEMES:
		if String(t["id"]) == id:
			return true
	return false


static func bg_name(id: String) -> String:
	for t in BG_THEMES:
		if String(t["id"]) == id:
			return String(t["name"])
	return id


## 从设置里读底色（和 [method UiText.apply] 一样，持有方读了设置就调一次）。
##
## 101 第 5 刀：[GameSettings] 不认识底色的名单，存的可能是空串或旧 id —— 认不出来就回到默认那档
static func apply(settings: GameSettings) -> void:
	bg_theme = settings.bg_theme if settings != null and has_bg_theme(settings.bg_theme) else BG_DEFAULT
#endregion


#region 按钮（090，作者定）
## 按钮按重要性分三档：字号是原来的 300% / 200% / 150%，颜色也各不同、都比默认灰扣显眼。
## 主动作（出发 / 开战 / 继续 / 全部拾取、地图右栏的三个）是琥珀色实底；次要（关闭 / 回主菜单 / 挑章节）是蓝灰实底亮边；
## 辅助（设置 / 随机种子 / 开关）是深底细边。谁是哪一档由各屏定，[method style_button] 只管画
enum Tier { PRIMARY, SECONDARY, MINOR }
const TIER_SCALE := {Tier.PRIMARY: 3.0, Tier.SECONDARY: 2.0, Tier.MINOR: 1.5}
const BTN_PRIMARY := Color("e6a83c")
const BTN_PRIMARY_HOVER := Color("f5bd5a")
const BTN_PRIMARY_TEXT := Color("15171c")
const BTN_SECONDARY := Color("2f3a4c")
const BTN_SECONDARY_HOVER := Color("3d4a60")
const BTN_SECONDARY_EDGE := Color("6f83a8")
const BTN_MINOR := Color("232932")
const BTN_MINOR_HOVER := Color("2f3641")
const BTN_MINOR_EDGE := Color("454d5c")
const BTN_DISABLED := Color("1b1f26")


## 这一档下、原字号 [param base] 该放大到多少
static func button_font_size(base: int, tier: int) -> int:
	return int(round(base * float(TIER_SCALE.get(tier, 2.0))))


## 给一个按钮上这一档的字号与配色（普通 / 停上 / 按下 / 禁用四态；开关按钮按下 = 亮边）
static func style_button(b: Button, tier: int, font_size: int) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	var bg: Color
	var hover: Color
	var edge: Color
	var text: Color
	match tier:
		Tier.PRIMARY:
			bg = BTN_PRIMARY
			hover = BTN_PRIMARY_HOVER
			edge = BTN_PRIMARY_HOVER
			text = BTN_PRIMARY_TEXT
		Tier.MINOR:
			bg = BTN_MINOR
			hover = BTN_MINOR_HOVER
			edge = BTN_MINOR_EDGE
			text = FG
		_:
			bg = BTN_SECONDARY
			hover = BTN_SECONDARY_HOVER
			edge = BTN_SECONDARY_EDGE
			text = FG
	var pad_h := int(round(font_size * 0.6))
	var pad_v := int(round(font_size * 0.3))
	b.add_theme_stylebox_override("normal", _button_box(bg, edge, pad_h, pad_v))
	b.add_theme_stylebox_override("hover", _button_box(hover, edge.lightened(0.2), pad_h, pad_v))
	b.add_theme_stylebox_override("pressed", _button_box(hover, Color.WHITE.lerp(edge, 0.3), pad_h, pad_v))
	b.add_theme_stylebox_override("hover_pressed", _button_box(hover, Color.WHITE.lerp(edge, 0.2), pad_h, pad_v))
	b.add_theme_stylebox_override("disabled", _button_box(BTN_DISABLED, LINE, pad_h, pad_v))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, text)
	b.add_theme_color_override("font_disabled_color", DIM)


static func _button_box(bg: Color, edge: Color, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s
#endregion
