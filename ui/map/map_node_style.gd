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

## 267 C：材料节点 —— 类型仍是 search，按 `content.search_kind` 换长相（搜索黄的四个变体）；键 `search_<种类>`，图标 `assets/nodes/search_<种类>.png`
const KINDS := {
	&"search_mine": {"glyph": "矿", "color": Color("c48a3a")},
	&"search_grove": {"glyph": "林", "color": Color("9aa63c")},
	&"search_remains": {"glyph": "遗", "color": Color("a8906a")},
	&"search_runes": {"glyph": "符", "color": Color("b58ad0")},
}
## 图例短名（同 [constant NAMES]，界面按语言取 `node.short.<键>`）
const KIND_NAMES := {
	&"search_mine": "矿脉", &"search_grove": "林地", &"search_remains": "遗骸", &"search_runes": "符文堆",
}

## 166（作者定）：左下角图例用的短名（地图上一眼看的那种；岔路口不列）。长名（事件文本、日志）照旧在 [NodeText]。
## 221 F1：值是中文原文，界面按语言取用 [method name_of]；表本身还管「图例列不列」
const NAMES := {
	&"battle": "战斗", &"elite": "精英", &"event": "事件", &"random": "未知", &"search": "搜索", &"shop": "商店",
	&"rest": "休息", &"extract": "撤离", &"core": "核心", &"spawn": "出生", &"safe": "保险箱", &"chest": "宝箱",
}

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
	var style: Dictionary = STYLES.get(type, KINDS.get(type, UNKNOWN)).duplicate()
	style["label"] = NodeText.label_of(type)
	return style


## 155：这种点的图标（白色线稿，画的时候按 [code]color[/code] 着色）；没有图返回 null，调用方画 glyph
static func icon(type: StringName) -> Texture2D:
	if not _icons.has(type):
		_icons[type] = EventImage.load_texture("%s/%s.png" % [ICON_DIR, type])
	return _icons[type]


## 267：这个点按什么画 —— 揭开了的随机点按揭开的类型；搜索点带材料种类（且有这种长相）就是 `search_<种类>`
static func key_of(n: MapNode) -> StringName:
	var key := kind_key(n)
	return key if key != &"" else NodeEvents.effective_type(n)


## 267：材料节点的长相键 `search_<种类>`；不是材料节点返回空
static func kind_key(n: MapNode) -> StringName:
	if n == null or n.type != &"search":
		return &""
	var key := StringName("search_" + String(n.content.get("search_kind", "")))
	return key if KINDS.has(key) else &""


static func route_color(index: int) -> Color:
	return ROUTE_COLORS[posmod(index, ROUTE_COLORS.size())]


## 166：图例里的短名（221 F1：按当前语言，`UiText` 的 `node.short.<type>`）；表里没有的退回 [NodeText] 的长名
static func name_of(type: StringName) -> String:
	if KIND_NAMES.has(type):
		return UiText.pick(UiText.TEXT.get("node.short.%s" % type), String(KIND_NAMES[type]))
	if not NAMES.has(type):
		return NodeText.label_of(type)
	return UiText.pick(UiText.TEXT.get("node.short.%s" % type), String(NAMES[type]))
