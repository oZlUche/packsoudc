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


## 209：放在 [param board] 上的这一件值多少 —— 整件在一个包里就乘那个包的 [member ItemDef.bag_value_mult]（百宝囊），其余同 [method of_instance]
static func of_in(inst: ItemInstance, board: ItemContainer) -> int:
	var base := of_instance(inst)
	var bag := ItemWeight.bag_def_of(inst, board)
	return base if bag == null or bag.bag_value_mult == 1.0 else maxi(1, roundi(float(base) * bag.bag_value_mult))


## 148：这一件值多少 —— 用坏了（[method ItemInstance.is_broken]）按 [member WearProfile.broken_value_ratio] 打折，至少 1；其余同 [method of]
static func of_instance(inst: ItemInstance) -> int:
	if inst == null or inst.def == null:
		return 0
	if inst.state.has("value"):
		return maxi(0, int(inst.state["value"]))     # 175：铸牌的价值记在实例上（补充二：固定价）
	var full := of(inst.def)
	if inst.is_broken():
		return maxi(1, int(roundf(float(full) * inst.def.wear.broken_value_ratio)))
	return full
