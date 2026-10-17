## 节点类型的清单（架构文档 5.4）。
##
## 数据层只要这一份名单：编辑器的下拉框、界面的配色表、将来的类型分配都从这里取，
## 不各自抄一遍 —— 抄出来的第二份迟早少一项。
class_name MapNodeTypes
extends RefCounted

const ALL: Array[StringName] = [
	&"battle", &"elite", &"event", &"random", &"search",
	&"shop", &"rest", &"extract", &"junction", &"core", &"spawn",
	&"safe",     # 092（作者定）：保险箱 —— 放进去的道具视为已带出
	&"chest",     # 154（作者定）：宝箱 —— 长按开锁，开了就是一次搜索
]


## 结构性的类型：由拓扑决定，类型分配与校准不拿它们当「事件点」换来换去
const STRUCTURAL: Array[StringName] = [&"core", &"spawn", &"extract", &"junction"]


## 182：每一类节点一句说明（对玩家说的话）—— 开局第三页点出生点时居中弹的提示窗用；章节的浮窗文字（`ChapterDef.tooltip_texts`）有就先用那份
const HINTS := {
	&"battle": "有人守着，过去就得打一场。",
	&"elite": "守着这里的是狠角色，打赢了收获也大。",
	&"event": "这里可能会发生什么，踩上去才知道。",
	&"random": "看不透的地方，踩上去才知道是什么。",
	&"search": "有值得翻一翻的东西，翻得越久越可能惊动附近的人。",
	&"shop": "有人在这里做买卖。",
	&"rest": "能歇脚的地方，回一点体力。",
	&"extract": "撤离点：站上去就能结束这一局、带着东西离开。",
	&"junction": "几条路在这里交汇。",
	&"core": "这张图的核心，最强的守卫在这里。",
	&"spawn": "从这里进图。挑一个入口，这一局就从它开始走。",
	&"safe": "保险箱：放进去的东西就算带出去了。",
	&"chest": "上锁的宝箱，长按开锁。",
}


static func has(type: StringName) -> bool:
	return ALL.has(type)


## `no_adjacent` 规则：这一对类型是不是列在「不许相邻」的表里（顺序不论）。
## 表里的一对可能是 String 也可能是 StringName（配置里的、过了 JSON 的图上的），都按字符串比
static func pair_forbidden(pairs: Array, a: StringName, b: StringName) -> bool:
	var sa := String(a)
	var sb := String(b)
	for pair in pairs:
		if (String(pair[0]) == sa and String(pair[1]) == sb) or (String(pair[0]) == sb and String(pair[1]) == sa):
			return true
	return false
