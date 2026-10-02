## 信仰的**标签词汇**（101 第 5 刀，规则见 [FaithState]）。
##
## 信仰是道具的一级分类，靠标签成立：信仰道具带 `faith`，再带一个信仰对象标签 `faith:<id>`。
## 哪位神、几阶、什么效果都是 `core/run` 的事（[FaithDef]），但**「标签长什么样」是道具层自己的词汇** ——
## 背包、套装、编译器都要读它，所以它住在这里，`core/inventory` 不必认识信仰体系（架构文档 1 节的依赖方向）。
class_name FaithTags
extends RefCounted

## 信仰对象标签的前缀：`faith:violence`
const PREFIX := "faith:"


## 这个信仰 id 的对象标签
static func tag_of(id: StringName) -> StringName:
	return StringName(PREFIX + String(id)) if id != &"" else &""


## 从对象标签取回信仰 id；不是对象标签返回空
static func id_of_tag(tag: StringName) -> StringName:
	var s := String(tag)
	return StringName(s.substr(PREFIX.length())) if s.begins_with(PREFIX) else &""
