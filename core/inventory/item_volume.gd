## 道具的体积档（093，作者附表）：按形状的格子数分五档 —— 极小 1 / 小 2～4 / 中 5～8 / 大 9～12 / 极大 13+。
## 信仰的增长条件（触发中体积以上的道具）与献祭品（大体积的道具）都按它算；纯查表，不碰任何系统。
class_name ItemVolume
extends RefCounted

## 档位序号 0～4 的名字（[method grade_name]）
const NAMES := ["极小", "小", "中", "大", "极大"]
## 各档的格子数下限（上一档的上限 + 1）
const FLOORS := [1, 2, 5, 9, 13]


static func cells_of(def: ItemDef) -> int:
	return def.cell_count() if def != null else 0


static func grade_of_cells(n: int) -> int:
	var g := 0
	for i in FLOORS.size():
		if n >= int(FLOORS[i]):
			g = i
	return g


static func grade_name(g: int) -> String:
	return NAMES[clampi(g, 0, NAMES.size() - 1)]


## 188 补充一（作者定「占 9 格以上」叫「大型道具」）：这一档的玩家叫法「X型道具」
static func size_label(g: int) -> String:
	return "%s型道具" % grade_name(g)
