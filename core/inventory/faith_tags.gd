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


## 信仰那边挑道具的共用条件（献祭品、赐福模板）：[param tags] 任一命中（空 = 不看标签）、格子数 ≥ [param min_cells]（0 = 不限）、
## 体积恰好 [param exact_grade] 档（-1 = 不限）。条件之间是「且」；def 为 null 不算
static func item_matches(def: ItemDef, tags: Array[StringName], min_cells: int, exact_grade: int) -> bool:
	if def == null:
		return false
	if not tags.is_empty():
		var hit := false
		for t in tags:
			if def.tags.has(t):
				hit = true
				break
		if not hit:
			return false
	var cells := ItemVolume.cells_of(def)
	if min_cells > 0 and cells < min_cells:
		return false
	if exact_grade >= 0 and ItemVolume.grade_of_cells(cells) != exact_grade:
		return false
	return true
