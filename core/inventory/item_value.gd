## 道具本身的价值（架构文档 6.4）。
##
## 道具有两种用处：**提供战斗力**，以及**本身值钱** —— 撤离结算、买卖、侵蚀损坏时的损失
## 都看后者。一件占 6 格的传说护甲可能打起来不如两把匕首，但背出去的价钱高得多；
## 「为了背它出去牺牲两格战斗力」正是搜刮路线上该有的取舍。
##
## 默认按**稀有度 × 尺寸**算：越稀有每格越贵，越大总价越高。`ItemDef.value` 填正数则覆盖，
## 留给「小而贵」或「大而贱」的特例。
class_name ItemValue
extends RefCounted

## 稀有度 → 每格基础价。**占位数值**，等经济系统（M4 / M5）拍板；
## 这里只保证「越稀有越贵」这个形状成立。
const BASE_PER_CELL: Array[int] = [5, 12, 30, 75, 200]


static func of(def: ItemDef) -> int:
	if def == null:
		return 0
	if def.value > 0:
		return def.value
	var tier := clampi(def.rarity, 0, BASE_PER_CELL.size() - 1)
	var cells := def.cell_count()
	return BASE_PER_CELL[tier] * cells


## 148：这一件值多少 —— 用坏了（[method ItemInstance.is_broken]）按 [member WearProfile.broken_value_ratio] 打折，至少 1；其余同 [method of]
static func of_instance(inst: ItemInstance) -> int:
	if inst == null or inst.def == null:
		return 0
	var full := of(inst.def)
	if inst.is_broken():
		return maxi(1, int(roundf(float(full) * inst.def.wear.broken_value_ratio)))
	return full
