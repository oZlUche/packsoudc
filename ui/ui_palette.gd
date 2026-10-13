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
## 150 补 4：体力心「失去」的那颗（黑心，外面描一圈 DIM）
const HEART_LOST := Color("0a0a0c")
const ARMOR := Color("5bc0de")
## 106（作者定）：护甲不再是独立的一条，而是生命条外侧的一圈粗白框 —— 这是那圈框的颜色
const ARMOR_FRAME := Color("f2f6ff")
const STAMINA := Color("f0ad4e")
const MANA := Color("7a8cf0")
const HEAL := Color("5cb85c")
## 104：暴击的飘字
const CRIT := Color("ffd23f")

## 邻接标记的两个方向。**按语义分色，不是按形状** ——
## 参照作品用星形／菱形区分，那只是两个任意符号；这里直接用颜色 + 文字。
const GRANT := Color("6fb3f0")    ## 增益：我给站在这儿的邻居加成
const FAITH := Color("c79bf2")    ## 113：信仰名（{faith:id}）
const RECEIVE := Color("f0a85c")  ## 受益：站在这儿的邻居给我加成

## 资源键 → 条的颜色。未登记的资源用 DIM，不至于看不见。
const RESOURCE_COLORS := {
	"hp": HP,
	"armor": ARMOR,
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
	"fg": FG, "dim": DIM, "hp": HP, "armor": ARMOR,
	"stamina": STAMINA, "mana": MANA, "heal": HEAL,
	"grant": GRANT, "receive": RECEIVE,
	"warn": STAMINA, "danger": HP, "good": HEAL, "faith": FAITH,
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


#region 字体（168）
## 168（作者定）：游戏自带字体 —— 正文霞鹜文楷（裁字子集，改名 PackSDC Kai，见 assets/fonts/README.md）、标题朱雀仿宋、大标题马善政。
## 子集只含文案里出现过的字（`tools/font_charset.py`），缺的字走后备：文楷后备系统字体，标题后备文楷 Medium，大标题后备标题字体。
## 文件不在（裁错、夹具）就退回系统字体，不崩
const FONT_DIR := "res://assets/fonts/"
const FONT_REGULAR := "wenkai_regular.ttf"
const FONT_MEDIUM := "wenkai_medium.ttf"
const FONT_TITLE := "zhuque_fangsong.ttf"
const FONT_DISPLAY := "mashanzheng.ttf"
static var _font_files: Dictionary = {}


## 一个打包的字体文件（缓存一次）；不在返回 null
static func font_file(file: String) -> FontFile:
	if not _font_files.has(file):
		var path := FONT_DIR + file
		_font_files[file] = load(path) as FontFile if ResourceLoader.exists(path) else null
	return _font_files[file]


## 系统字体（168 之前的默认字体，现在是后备）：Godot 内置字体不含 CJK 字形，中文会显示成方块
static func system_font(bold: bool = false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(
		["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"]
	)
	if bold:
		f.font_weight = 700
	return f


## 包一层：[param file] 打底，缺字走 [param fallback]；文件不在就直接是 [param fallback]
static func _wrap(file: String, fallback: Font) -> Font:
	var base := font_file(file)
	if base == null:
		return fallback
	var v := FontVariation.new()
	v.base_font = base
	v.fallbacks = [fallback]
	return v


## 正文、读数、按钮：文楷 Regular
static func cjk_font() -> Font:
	return _wrap(FONT_REGULAR, system_font())


## 真粗体：富文本的 [b] 用它（文楷 Medium，不让引擎把常规体描粗 —— 描出来的发糊）
static func cjk_font_bold() -> Font:
	return _wrap(FONT_MEDIUM, system_font(true))


## 标题、名牌：朱雀仿宋（技术预览版，缺字时混进文楷 Medium）
static func title_font() -> Font:
	return _wrap(FONT_TITLE, cjk_font_bold())


## 大标题（主菜单游戏名、章节名、宝箱屏说明）：马善政，缺字走标题字体
static func display_font() -> Font:
	return _wrap(FONT_DISPLAY, title_font())
#endregion


#region 背景底色（091）
## [constant BG_THEMES] 里 id 是 [param id] 的那一档；没有这一档返回空字典
static func theme_of(id: String) -> Dictionary:
	for t in BG_THEMES:
		if String(t["id"]) == id:
			return t
	return {}


static func bg() -> Color:
	return theme_of(bg_theme).get("color", BG_THEMES[0]["color"])


static func has_bg_theme(id: String) -> bool:
	return not theme_of(id).is_empty()


## 从设置里读底色（和 [method UiText.apply] 一样，持有方读了设置就调一次）。
##
## 101 第 5 刀：[GameSettings] 不认识底色的名单，存的可能是空串或旧 id —— 认不出来就回到默认那档
static func apply(settings: GameSettings) -> void:
	bg_theme = settings.bg_theme if settings != null and has_bg_theme(settings.bg_theme) else BG_DEFAULT
	UiTheme.refresh(settings)     # 121：面板底色跟着底色走，挂着的主题原地重填
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


## 给一个按钮上这一档的样式。121：样式在 [UiTheme] 的按钮变体里（四态配色、内边距），这里只选变体；
## 字号不是这一档的默认值（14 号的 300% / 200% / 150%）时才单独给字号
static func style_button(b: Button, tier: int, font_size: int) -> void:
	b.theme_type_variation = button_variation(tier)
	if font_size != button_font_size(UiTheme.FONT_SIZE, tier):
		b.add_theme_font_size_override("font_size", font_size)


## 这一档对应的按钮变体名（[UiTheme]）
static func button_variation(tier: int) -> StringName:
	match tier:
		Tier.PRIMARY:
			return UiTheme.BUTTON_PRIMARY
		Tier.MINOR:
			return UiTheme.BUTTON_DIM
	return UiTheme.BUTTON_SECONDARY
#endregion


## 161：一颗心（HUD 体力、开局屏角色卡共用）：两个圆 + 一个朝下的三角，外面一圈暗线（黑心在深底上也看得见）。
## [param at] 是 [param s] × [param s] 方块的左上角
static func draw_heart(canvas: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var r := s * 0.27
	var l := at + Vector2(s * 0.29, s * 0.33)
	var rr := at + Vector2(s * 0.71, s * 0.33)
	var tri := PackedVector2Array([at + Vector2(s * 0.04, s * 0.42), at + Vector2(s * 0.96, s * 0.42), at + Vector2(s * 0.5, s * 0.95)])
	canvas.draw_circle(l, r, col)
	canvas.draw_circle(rr, r, col)
	canvas.draw_colored_polygon(tri, col)
	var edge := DIM
	canvas.draw_arc(l, r, PI * 0.8, PI * 2.0, 12, edge, 1.0, true)
	canvas.draw_arc(rr, r, PI, PI * 2.2, 12, edge, 1.0, true)
	canvas.draw_line(tri[0], tri[2], edge, 1.0, true)
	canvas.draw_line(tri[1], tri[2], edge, 1.0, true)
