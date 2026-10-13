## 129：一件道具有多重（单位「重」）。137：按名称与标签重配，金属更重。
##
## 写死的（[member ItemDef.weight] > 0）用写死的；否则 = 格数 × 每格重，每格重按材质类取（按标签，从上到下取第一个命中）：
## [codeblock]
## heavy                                              每格 4
## metal（武器、甲、盾、矿石、锭、枪）                每格 3
## gem / stone（宝石、晶体、石头、盐块）               每格 2
## remedy / food / ammo / keepsake / sigil / treasure / relic   半格一重，向上取整
## 其余（木、骨、皮、布、陶、皮包……）                每格 1
## [endcodeblock]
## 161（作者定）：**包不算重** —— 作为包的道具（`is_bag`）一律 0，写死值也不看。
## 公式只是默认值，让新加的道具不填也有一个说得过去的数；名字说它和材质不符的才写死在道具文件里（报告 129 附录 A、137 第二节）
class_name ItemWeight
extends RefCounted

const HEAVY := &"heavy"
const METAL := &"metal"
## 137：石与晶这一档（宝石或新加的石材标签，任一命中）
const STONE_TAGS: Array[StringName] = [&"gem", &"stone"]
const LIGHT_TAGS: Array[StringName] = [&"remedy", &"food", &"ammo", &"keepsake", &"sigil", &"treasure", &"relic"]
const PER_CELL_HEAVY := 4
const PER_CELL_METAL := 3
const PER_CELL_STONE := 2


static func of(def: ItemDef) -> int:
	if def == null or def.is_bag:
		return 0
	if def.weight > 0:
		return def.weight
	return formula(def)


## 不看写死值的公式值（编辑器、报告对照用）
static func formula(def: ItemDef) -> int:
	if def == null or def.is_bag:
		return 0
	var cells := def.cell_count()
	if def.tags.has(HEAVY):
		return cells * PER_CELL_HEAVY
	if def.tags.has(METAL):
		return cells * PER_CELL_METAL
	for t in STONE_TAGS:
		if def.tags.has(t):
			return cells * PER_CELL_STONE
	for t in LIGHT_TAGS:
		if def.tags.has(t):
			return maxi(1, ceili(cells / 2.0))
	return maxi(1, cells)


## 一块容器里所有东西的重量之和（161：包是 0，所以棋盘上就是不含包）
static func total(c: ItemContainer) -> int:
	var sum := 0
	if c == null:
		return sum
	for inst in c.items():
		sum += of((inst as ItemInstance).def)
	return sum
