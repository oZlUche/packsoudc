## 节点类型 → 画成什么样。名单来自 [MapNodeTypes]，这里只管长相。
##
## 101 第 5 刀：**名字不在这里** —— 它是文字，住在 [NodeText]（`core/text`），事件文本与日志用的是同一份。
## [method of] 把名字接回来，调用方照旧读 `label`
class_name MapNodeStyle
extends RefCounted

## type → {glyph 画在圆里的一个字, color}；名字见 [NodeText.LABELS]。
## 155（作者定）：节点用图标 —— `res://assets/nodes/<type>.png`（[method icon]，白色线稿、按 color 着色）；缺图的退回画 glyph
const STYLES := {
	&"battle": {"glyph": "战", "color": Color("c9605a")},
	&"elite": {"glyph": "精", "color": Color("e0457a")},
	&"event": {"glyph": "事", "color": Color("6f9fe0")},
	&"random": {"glyph": "？", "color": Color("9b7ff0")},
	&"search": {"glyph": "搜", "color": Color("e0b04a")},
	&"shop": {"glyph": "店", "color": Color("4fc0b0")},
	&"rest": {"glyph": "休", "color": Color("5cb85c")},
	&"extract": {"glyph": "撤", "color": Color("dfe3ea")},
	&"junction": {"glyph": "·", "color": Color("5a6270")},
	&"core": {"glyph": "核", "color": Color("ff4a3d")},   # 红，始终可见：玩家的方向锚点（5.9）
	&"spawn": {"glyph": "生", "color": Color("5cb85c")},
	&"safe": {"glyph": "箱", "color": Color("c8a2ff")},   # 092：放进去的就算带出去了
	&"chest": {"glyph": "宝", "color": Color("c98a3c")},   # 154：金棕，和搜索的黄分开（终值等美术）
}

const UNKNOWN := {"glyph": "?", "color": Color("8b93a1")}

## 155：节点图标的目录（文件名 = 类型）
const ICON_DIR := "res://assets/nodes"

## 155：类型 → 图标（没有图为 null），读一次就记住
static var _icons: Dictionary = {}

## 路线的描边色，按路线下标轮流取
const ROUTE_COLORS: Array[Color] = [
	Color("ff8a7a"), Color("e0b04a"), Color("6fb3f0"), Color("8ed36b"), Color("c9a0ff"),
]


## 这种点画成什么样 + 它叫什么（`{glyph, color, label}`）。名字从 [NodeText] 取
static func of(type: StringName) -> Dictionary:
	var style: Dictionary = STYLES.get(type, UNKNOWN).duplicate()
	style["label"] = NodeText.label_of(type)
	return style


## 155：这种点的图标（白色线稿，画的时候按 [code]color[/code] 着色）；没有图返回 null，调用方画 glyph
static func icon(type: StringName) -> Texture2D:
	if not _icons.has(type):
		_icons[type] = EventImage.load_texture("%s/%s.png" % [ICON_DIR, type])
	return _icons[type]


static func route_color(index: int) -> Color:
	return ROUTE_COLORS[posmod(index, ROUTE_COLORS.size())]
