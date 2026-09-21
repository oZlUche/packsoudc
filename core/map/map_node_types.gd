## 节点类型的清单（架构文档 5.4）。
##
## 数据层只要这一份名单：编辑器的下拉框、界面的配色表、将来的类型分配都从这里取，
## 不各自抄一遍 —— 抄出来的第二份迟早少一项。
class_name MapNodeTypes
extends RefCounted

const ALL: Array[StringName] = [
	&"battle", &"elite", &"event", &"random", &"search",
	&"shop", &"rest", &"extract", &"junction", &"core",
]


static func has(type: StringName) -> bool:
	return ALL.has(type)
