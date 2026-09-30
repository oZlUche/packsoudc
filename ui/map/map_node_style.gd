## 节点类型 → 画成什么样。名单来自 [MapNodeTypes]，这里只管长相。
class_name MapNodeStyle
extends RefCounted

## type → {label 全称, glyph 画在圆里的一个字, color}
const STYLES := {
	&"battle": {"label": "战斗", "glyph": "战", "color": Color("c9605a")},
	&"elite": {"label": "精英战斗", "glyph": "精", "color": Color("e0457a")},
	&"event": {"label": "事件", "glyph": "事", "color": Color("6f9fe0")},
	&"random": {"label": "随机", "glyph": "？", "color": Color("9b7ff0")},
	&"search": {"label": "搜索点", "glyph": "搜", "color": Color("e0b04a")},
	&"shop": {"label": "商店", "glyph": "店", "color": Color("4fc0b0")},
	&"rest": {"label": "休息区", "glyph": "休", "color": Color("5cb85c")},
	&"extract": {"label": "撤离点", "glyph": "撤", "color": Color("dfe3ea")},
	&"junction": {"label": "岔路", "glyph": "·", "color": Color("5a6270")},
	&"core": {"label": "核心", "glyph": "核", "color": Color("ff4a3d")},   # 红，始终可见：玩家的方向锚点（5.9）
	&"spawn": {"label": "出生点", "glyph": "生", "color": Color("5cb85c")},
	&"safe": {"label": "保险箱", "glyph": "箱", "color": Color("c8a2ff")},   # 092：放进去的就算带出去了
}

const UNKNOWN := {"label": "未知", "glyph": "?", "color": Color("8b93a1")}

## 路线的描边色，按路线下标轮流取
const ROUTE_COLORS: Array[Color] = [
	Color("ff8a7a"), Color("e0b04a"), Color("6fb3f0"), Color("8ed36b"), Color("c9a0ff"),
]


static func of(type: StringName) -> Dictionary:
	return STYLES.get(type, UNKNOWN)


static func route_color(index: int) -> Color:
	return ROUTE_COLORS[posmod(index, ROUTE_COLORS.size())]
