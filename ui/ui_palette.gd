## 界面共用的配色与字体。
##
## 抽出来是因为两个沙盒各自复制过一份 —— 复制出来的第二份迟早跟第一份长得不一样。
class_name UiPalette
extends RefCounted

const BG := Color("101216")
const PANEL := Color("171a20")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")
const LINE := Color("2a2f38")

const HP := Color("d9534f")
const SHIELD := Color("5bc0de")
const STAMINA := Color("f0ad4e")
const MANA := Color("7a8cf0")
const HEAL := Color("5cb85c")

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


static func damage_color(type: StringName) -> Color:
	return DAMAGE_COLORS.get(String(type), FG)


## Godot 内置字体不含 CJK 字形，中文会显示成方块
static func cjk_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(
		["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"]
	)
	return f


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
