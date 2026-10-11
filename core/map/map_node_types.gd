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
