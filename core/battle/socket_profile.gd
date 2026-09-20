## 物品的星形／菱形插槽（架构文档 4.2）。
##
## 插槽格是物品[b]轮廓之外[/b]的相邻格，偏移相对物品原点书写，
## 随物品一起旋转（走 [method ItemShape.transform_point]，与形状共用同一套平移）。
##
## 点亮规则是[b]去重计数[/b]：一件物品最多只能填另一件的一个星、一个菱形，
## 所以「点亮数 = 占住插槽格的不同物品数量」。这与遍历顺序无关，不需要匹配算法。
##
## [b]硬约束：同一件物品的所有星必须同质。[/b] 若某天要让一号星管伤害、二号星管冷却，
## 就得先决定「谁分配到哪个星」，问题会退化成二分匹配 —— 越这条线之前先改架构文档 4.2。
class_name SocketProfile
extends Resource

enum Direction {
	HOLDER,  ## 受益的是插槽持有者：「★ 处的食物让我触发更快」
	FILLER,  ## 受影响的是填充者：「我触发时，连带触发 ★ 处的物品」
}

@export_group("星形")
## 星格偏移，相对物品原点
@export var star_cells: Array[Vector2i] = []
## 填充条件：为空表示任何物品都算，否则填充者的标签需命中其一
@export var star_filter: Array[StringName] = []
@export var star_direction: Direction = Direction.HOLDER
@export var star_mods: Array[StatModifier] = []

@export_group("菱形")
@export var diamond_cells: Array[Vector2i] = []
@export var diamond_filter: Array[StringName] = []
@export var diamond_direction: Direction = Direction.HOLDER
@export var diamond_mods: Array[StatModifier] = []


func has_star() -> bool:
	return not star_cells.is_empty() and not star_mods.is_empty()


func has_diamond() -> bool:
	return not diamond_cells.is_empty() and not diamond_mods.is_empty()


## 某个定义是否能填本插槽。
static func accepts(filter: Array[StringName], def: ItemDef) -> bool:
	if filter.is_empty():
		return true
	if def == null:
		return false
	for tag in def.tags:
		if filter.has(tag):
			return true
	return false
