## 事件选项的代价图标（157）：选项按钮文字前一排小格，只画「会花掉什么」，不画「会得到什么」（读完才知道的乐趣）。
##
## 每种一格 16 像素：`assets/ui/cost_<种>.png` 有图用图，没图在那一格写字符。哪些后果 / 条件算哪种代价写在 [member KINDS] 里 ——
## 新的后果类加一行就有图标。拼成一张图挂在按钮的 `icon` 上（按钮自己把它排在字前面，不加子控件、不加覆写）
class_name EventCostIcons
extends RefCounted

const SIZE := 16
const GAP := 4
## [类, 种, 没图时写的字符, 说法]；钱只有花钱（数是负的）才算
static var KINDS: Array = [
	[SpendVitality, "vitality", "♥", "耗体力"],
	[ChangeMoney, "money", "¤", "花钱"],
	[LoseItem, "item", "▣", "交出道具"],
	[PassTime, "time", "⌛", "耗行动点"],
	[FaithActive, "faith", "✦", "要信仰"],
]


## 这个选项的代价（按 [member KINDS] 的顺序，不重复）：后果里的花费 + 条件里的信仰
static func kinds_of(opt: EventOption) -> Array[String]:
	var hit := {}
	for o in opt.outcomes:
		var k := _kind_of(o)
		if k != "":
			hit[k] = true
	for c in opt.requires:
		var k2 := _kind_of(c)
		if k2 != "":
			hit[k2] = true
	var out: Array[String] = []
	for row in KINDS:
		if hit.has(String(row[1])):
			out.append(String(row[1]))
	return out


static func _kind_of(thing: Object) -> String:
	if thing == null:
		return ""
	for row in KINDS:
		if is_instance_of(thing, row[0]):
			if thing is ChangeMoney and (thing as ChangeMoney).amount >= 0:
				return ""
			return String(row[1])
	return ""


static func glyph_of(kind: String) -> String:
	for row in KINDS:
		if String(row[1]) == kind:
			return String(row[2])
	return "?"


## 「代价：耗体力、花钱」（按钮的悬浮提示）
static func describe(kinds: Array[String]) -> String:
	var words: Array[String] = []
	for row in KINDS:
		if kinds.has(String(row[1])):
			words.append(String(row[3]))
	return "代价：" + "、".join(words) if not words.is_empty() else ""


## 一排代价拼成的一张图（没有代价 null）。没图的那几种在图上留空，[method glyph_slots] 说哪几格要画字符
static func strip(kinds: Array[String]) -> Texture2D:
	if kinds.is_empty():
		return null
	var img := Image.create_empty(kinds.size() * (SIZE + GAP) - GAP, SIZE, false, Image.FORMAT_RGBA8)
	for i in kinds.size():
		var tex := UiTheme.art("cost_" + kinds[i])
		if tex == null:
			continue
		var src := tex.get_image()
		if src == null or src.is_empty():
			continue
		src = src.duplicate()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		if src.get_width() != SIZE or src.get_height() != SIZE:
			src.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
		img.blit_rect(src, Rect2i(0, 0, SIZE, SIZE), Vector2i(i * (SIZE + GAP), 0))
	return ImageTexture.create_from_image(img)


## 哪几格没有图（要在按钮上补画字符）
static func glyph_slots(kinds: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for i in kinds.size():
		if UiTheme.art("cost_" + kinds[i]) == null:
			out.append(i)
	return out


## 给一个选项按钮挂上代价：图挂在 `icon`、没图的格子在按钮上画字符、悬浮提示写代价。返回挂了几种
static func attach(b: Button, opt: EventOption) -> int:
	var kinds := kinds_of(opt)
	b.set_meta("costs", kinds)
	if kinds.is_empty():
		return 0
	b.icon = strip(kinds)
	b.tooltip_text = describe(kinds)
	var missing := glyph_slots(kinds)
	if not missing.is_empty():
		b.draw.connect(func():
			var font := b.get_theme_font("font")
			var left := b.get_theme_stylebox("normal").get_margin(SIDE_LEFT)
			var top := (b.size.y - SIZE) * 0.5
			for i in missing:
				b.draw_string(font, Vector2(left + i * (SIZE + GAP), top + SIZE - 2), glyph_of(kinds[i]),
					HORIZONTAL_ALIGNMENT_CENTER, SIZE, SIZE, UiPalette.FG))
	return kinds.size()
