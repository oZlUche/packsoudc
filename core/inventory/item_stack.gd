## 大地之神【压缩】：可堆叠的道具（[member ItemDef.stackable]，大地结晶）—— 同种、每个的价值与重量一样的拖到一起叠成一摞。
## 一摞几个记在实例上（[method ItemInstance.stack_count]），价值、重量按个数乘（[ItemValue]、[ItemWeight]）
class_name ItemStack
extends RefCounted


## [param a] 能不能叠到 [param b] 上
static func can_merge(a: ItemInstance, b: ItemInstance) -> bool:
	if a == null or b == null or a == b or a.def == null or b.def == null or not a.def.stackable:
		return false
	if a.def.id != b.def.id:
		return false
	for k in ["value", ItemInstance.WEIGHT_ADD_KEY, ItemWeight.WEIGHT_MULT_KEY]:
		if a.state.get(k, null) != b.state.get(k, null):
			return false
	return true


## 把 [param a]（在 [param a_home] 里）叠到 [param b]（在 [param b_home] 里）上：a 从原处拿走，b 的个数加上。返回叠上没有
static func merge(a: ItemInstance, a_home: ItemContainer, b: ItemInstance, b_home: ItemContainer = null) -> bool:
	if not can_merge(a, b) or a_home == null or not a_home.has_item(a.uid):
		return false
	var n := a.stack_count()
	if a_home.remove(a.uid) == null:
		return false
	b.set_stack(b.stack_count() + n)
	if b_home != null:
		b_home.touch()     # 个数变了：重画、负重重算
	return true
