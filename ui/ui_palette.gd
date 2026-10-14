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


## 资源键的颜色：hp / armor / stamina / mana 读字色模板里同名的那条（169），别的查 [constant RESOURCE_COLORS]，都没有 DIM
static func resource_color(key: StringName, tone: StringName = &"dark") -> Color:
	var styles: Dictionary = text_colors()["styles"]
	if RESOURCE_COLORS.has(String(key)) and styles.has(String(key)):
		return styles[String(key)][_side(tone)]
	return for_tone(RESOURCE_COLORS.get(String(key), DIM), tone)


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


## 把 BBCode 里的 `[color=@名字]` 换成真颜色。给 RichTextLabel 之前调（[TextTemplate.render] 的输出都要过这一道）。
## 169：按 [param tone] 取字色模板的深版 / 浅版（浅底暗字、深底亮字）
static func resolve_styles(bbcode: String, tone: StringName = &"dark") -> String:
	if not bbcode.contains("[color=" + TextTemplate.STYLE_PREFIX):
		return bbcode
	var out := bbcode
	var styles: Dictionary = text_colors()["styles"]
	for name in styles:
		out = out.replace("[color=%s%s]" % [TextTemplate.STYLE_PREFIX, name],
			"[color=#%s]" % (styles[name][_side(tone)] as Color).to_html(false))
	# 112：`{item:id}` 的名字按稀有度上色（和道具悬浮窗里的名字同色）
	var rarity: Array = text_colors()["rarity"]
	for r in rarity.size():
		out = out.replace("[color=%s%s%d]" % [TextTemplate.STYLE_PREFIX, TextTemplate.RARITY_STYLE, r],
			"[color=#%s]" % (rarity[r][_side(tone)] as Color).to_html(false))
	return out


## 169 统一入口：一段 BBCode 放到深 / 浅底上 —— 颜色名按模板取版；浅底时写死的十六进制再过一道 [method for_tone]
## （是模板里某个深版就换成它的浅版，别的按 [method UiTheme.ink_color] 压暗兜底）
static func toned(bbcode: String, tone: StringName) -> String:
	var out := resolve_styles(bbcode, tone)
	if tone != UiTheme.TONE_LIGHT or not out.contains("[color="):
		return out
	if _hex_tag == null:
		_hex_tag = RegEx.create_from_string("\\[color=#?([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)\\]")
	var res := ""
	var at := 0
	for m in _hex_tag.search_all(out):
		res += out.substr(at, m.get_start() - at)
		res += "[color=#%s]" % for_tone(Color(m.get_string(1)), tone).to_html(false)
		at = m.get_end()
	return res + out.substr(at)
#endregion


static func damage_color(type: StringName, tone: StringName = &"dark") -> Color:
	var dmg: Dictionary = text_colors()["damage"]
	if dmg.has(String(type)):
		return dmg[String(type)][_side(tone)]
	return style_color("fg", tone)


#region 字色模板（169，作者定：浅底一律暗字、深底一律亮字 —— 每个颜色名写两版，颜色由作者挑，不靠算法压）
## `data/authoring/ui/text_colors.json`：`styles`（样式码颜色名 + term / crit）、`rarity`（六档）、`damage`（每种伤害类型），
## 每条都要 `dark` 与 `light` 两版。文件不在、读不成或缺一条 = **整份不用**，回代码默认（深版是代码常量，浅版按 ink_color 压），问题记进 [member text_color_problems]
const TEXT_COLORS_PATH := "res://data/authoring/ui/text_colors.json"
const TEXT_COLORS_VERSION := 1
## 样式码之外模板里也要有的名字：术语链接、暴击飘字；170 定稿的悬浮窗三档字色（正文白、标签与脚注、说明）
const EXTRA_STYLES := ["term", "crit", "tip_fg", "tip_meta", "tip_desc"]
## 170 定稿（作者 2026-10-14）：悬浮窗正文白、标签与脚注比 dim 亮、斜体说明再暗一档 —— 只在深底悬浮窗上用
const TIP_COLORS := {"tip_fg": Color("f2eee6"), "tip_meta": Color("d8d2c8"), "tip_desc": Color("c9c2b8")}
static var text_colors_path := TEXT_COLORS_PATH
static var text_color_problems: Array[String] = []
static var _text_colors: Dictionary = {}
## 深版十六进制 → 浅版（浅底上碰到写死的颜色先查它）
static var _to_light: Dictionary = {}
## 浅版十六进制（已经是浅底用的，不再压）
static var _light_set: Dictionary = {}
static var _hex_tag: RegEx = null


## 模板（第一次用时读；[method load_text_colors] 重读）
static func text_colors() -> Dictionary:
	if _text_colors.is_empty():
		load_text_colors()
	return _text_colors


## 读（或重读）字色模板；返回问题（空 = 用的是文件）。可重入：启动器配色页 F5 就是再叫一次
static func load_text_colors(path: String = "") -> Array[String]:
	if path != "":
		text_colors_path = path
	var problems: Array[String] = []
	var parsed := {}
	UiTheme.reset_ink()     # 缺文件时浅版按代码默认的墨色压，不按上一份文件的
	if not FileAccess.file_exists(text_colors_path):
		problems.append("字色模板 %s 不在" % text_colors_path)
	else:
		var d = JSON.parse_string(FileAccess.get_file_as_string(text_colors_path))
		if not d is Dictionary:
			problems.append("字色模板 %s 读不成 JSON 字典" % text_colors_path)
		else:
			parsed = parse_text_colors(d, problems)
	text_color_problems = problems
	_text_colors = parsed if problems.is_empty() else default_text_colors()
	_index()
	UiTheme.text_colors_changed()
	return problems


## 校验并转成 {styles: {名: {dark, light}}, rarity: [{dark, light}×6], damage: {类型: {dark, light}}}（颜色是 Color）；问题追加进 [param problems]
static func parse_text_colors(d: Dictionary, problems: Array[String]) -> Dictionary:
	if int(d.get("version", 0)) != TEXT_COLORS_VERSION:
		problems.append("字色模板 version 应为 %d（现在 %s）" % [TEXT_COLORS_VERSION, str(d.get("version", "缺"))])
	var out := {"styles": {}, "rarity": [], "damage": {}}
	var styles = d.get("styles", {})
	for name in TextTemplate.STYLE_NAMES + EXTRA_STYLES:
		var pair = _pair(styles.get(name, null) if styles is Dictionary else null, "styles.%s" % name, problems)
		if pair != null:
			out["styles"][name] = pair
	var rarity = d.get("rarity", [])
	if not rarity is Array or (rarity as Array).size() != ItemPainter.RARITY_COLORS.size():
		problems.append("字色模板 rarity 要正好 %d 档" % ItemPainter.RARITY_COLORS.size())
	else:
		for r in (rarity as Array).size():
			var pair = _pair(rarity[r], "rarity[%d]" % r, problems)
			if pair != null:
				out["rarity"].append(pair)
	var dmg = d.get("damage", {})
	for type in damage_types():
		var pair = _pair(dmg.get(type, null) if dmg is Dictionary else null, "damage.%s" % type, problems)
		if pair != null:
			out["damage"][type] = pair
	return out


## 伤害类型（`data/authoring/damage_types/` 里每一种，再加代码里登记过的）
static func damage_types() -> Array[String]:
	var out: Array[String] = []
	for k in DAMAGE_COLORS:
		out.append(String(k))
	for f in DirAccess.get_files_at("res://data/authoring/damage_types"):
		if f.ends_with(".json") and not out.has(f.get_basename()):
			out.append(f.get_basename())
	return out


static func _pair(v: Variant, at: String, problems: Array[String]) -> Variant:
	if not v is Dictionary:
		problems.append("字色模板缺 %s（深版 dark、浅版 light 都要写）" % at)
		return null
	var out := {}
	for side in ["dark", "light"]:
		var h := String((v as Dictionary).get(side, ""))
		if not Color.html_is_valid(h):
			problems.append("字色模板 %s.%s 不是颜色（%s）" % [at, side, h])
			return null
		out[side] = Color.html(h)
	return out


## 文件不在时的模板：深版 = 代码常量（行为不变），浅版 = 按 ink_color 压暗（157 补的老办法）
static func default_text_colors() -> Dictionary:
	var styles := {}
	var dark := STYLE_COLORS.duplicate()
	dark["term"] = Glossary.TERM_COLOR
	dark["crit"] = CRIT
	dark.merge(TIP_COLORS)
	for name in dark:
		styles[name] = {"dark": dark[name], "light": UiTheme.ink_color(dark[name])}
	var rarity := []
	for c in ItemPainter.RARITY_COLORS:
		rarity.append({"dark": c, "light": UiTheme.ink_color(c)})
	var dmg := {}
	for type in damage_types():
		var c: Color = DAMAGE_COLORS.get(type, FG)
		dmg[type] = {"dark": c, "light": UiTheme.ink_color(c)}
	return {"styles": styles, "rarity": rarity, "damage": dmg}


static func _index() -> void:
	_to_light.clear()
	_light_set.clear()
	var pairs: Array = (_text_colors["styles"] as Dictionary).values() + (_text_colors["rarity"] as Array) + (_text_colors["damage"] as Dictionary).values()
	for pair in pairs:
		var dk := (pair["dark"] as Color).to_html(false)
		if not _to_light.has(dk):     # 同一个深版写了不同浅版（体力 / 警示）：先登记的算
			_to_light[dk] = pair["light"]
		_light_set[(pair["light"] as Color).to_html(false)] = true


static func _side(tone: StringName) -> String:
	return "light" if tone == UiTheme.TONE_LIGHT else "dark"


## 样式码颜色名（含 term / crit）在这个底上的颜色；不认得的名字按 fg
static func style_color(name: String, tone: StringName = &"dark") -> Color:
	var styles: Dictionary = text_colors()["styles"]
	return styles.get(name, styles["fg"])[_side(tone)]


## 稀有度在这个底上的颜色（棋盘格上的名字有自己的深底，用 [ItemPainter] 的，不走这里）
static func rarity_color(r: int, tone: StringName = &"dark") -> Color:
	var rarity: Array = text_colors()["rarity"]
	return rarity[clampi(r, 0, rarity.size() - 1)][_side(tone)]


## 一个按深底配的颜色放到这个底上：深底原样；浅底先查模板（某个深版 → 它的浅版），已经是浅版的不动，别的按 ink_color 压
static func for_tone(c: Color, tone: StringName) -> Color:
	if tone != UiTheme.TONE_LIGHT:
		return c
	text_colors()
	var h := c.to_html(false)
	if _to_light.has(h):
		return Color(_to_light[h], c.a)
	if _light_set.has(h):
		return c
	return Color(UiTheme.ink_color(c), c.a)
#endregion


#region 字体（168）
## 168（作者定）：游戏自带字体 —— 正文一套、标题朱雀仿宋、大标题马善政；170 定稿（作者 2026-10-14 挑 A）正文从霞鹜文楷换成思源宋体（Noto Serif CJK SC，
## Regular 正文、Bold 粗体，裁字子集，见 assets/fonts/README.md）。子集只含文案里出现过的字（`tools/font_charset.py`），
## 缺的字走后备：正文后备系统字体，标题后备思源宋体 Bold，大标题后备标题字体。
## 文件不在（裁错、夹具）就退回系统字体，不崩
const FONT_DIR := "res://assets/fonts/"
## 170 §5：正文 / 粗体按用途叫（原 FONT_REGULAR / FONT_MEDIUM）—— 换字体只换这两个文件名，调用点不动
const FONT_BODY := "serif_regular.otf"
const FONT_BOLD := "serif_bold.otf"
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


## 正文、读数、按钮：思源宋体 Regular
static func cjk_font() -> Font:
	return _wrap(FONT_BODY, system_font())


## 真粗体：富文本的 [b] 用它（思源宋体 Bold，不让引擎把常规体描粗 —— 描出来的发糊）
static func cjk_font_bold() -> Font:
	return _wrap(FONT_BOLD, system_font(true))


## 标题、名牌：朱雀仿宋（技术预览版，缺字时混进思源宋体 Bold）
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
