## 信仰的激活规则（第 8 阶段 8-4，报告 081；作者定）：**任何时刻只激活一个信仰 = 最后一个置入棋盘的信仰道具所属的那个。**
## 别的信仰的道具**休眠**：编译战斗单位时跳过它的战斗数据与邻接，套装也不计它（占格照占、价值照算）。
## 无信仰之物（不带 `faith` 标签）在任何信仰下都能用；棋盘上一件信仰道具都没有 = 没激活任何信仰（「不信者」现在只是这个状态）。
##
## 「最后置入」看 [member ItemInstance.placed_seq]（[GridInventory] 在道具从别的容器进来时盖的序号），
## 所以把一件挪到暂存区再挪回来就是切换。全是静态函数：只看容器与标签，不认具体的神、不持有状态。
class_name FaithState
extends RefCounted


## 棋盘上激活的信仰对象标签（`faith:xxx`）；没有信仰道具返回空
static func active_tag(container: ItemContainer) -> StringName:
	if container == null:
		return &""
	var best: ItemInstance = null
	for raw in container.items():
		var inst := raw as ItemInstance
		if inst == null or inst.def == null or not inst.def.has_faith():
			continue
		if best == null or inst.placed_seq > best.placed_seq or (inst.placed_seq == best.placed_seq and inst.uid > best.uid):
			best = inst
	return best.def.faith_tag() if best != null else &""


## 激活的信仰 id（`violence`）；没有返回空
static func active_id(container: ItemContainer) -> StringName:
	return FaithDef.id_of_tag(active_tag(container))


## 这件东西在这个激活信仰下是不是休眠的：有信仰、且不是激活的那个
static func is_dormant(def: ItemDef, active: StringName) -> bool:
	return def != null and def.has_faith() and def.faith_tag() != active


## 087（作者定）：休眠的这件还留着通用效果没有 —— 有战斗定义、且 [member ItemDef.dormant_keeps_combat] 开着。
## 留着 = 编译时仍参战（基础属性 + 自己的规则 + 包体加成），只丢信力加成、邻接、套装；不留 = 彻底不参战
static func keeps_combat_when_dormant(def: ItemDef) -> bool:
	return def != null and def.combat != null and def.dormant_keeps_combat


## 棋盘上休眠的那些 uid，升序
static func dormant_uids(container: ItemContainer) -> Array[int]:
	var out: Array[int] = []
	if container == null:
		return out
	var active := active_tag(container)
	for raw in container.items():
		var inst := raw as ItemInstance
		if inst != null and is_dormant(inst.def, active):
			out.append(inst.uid)
	out.sort()
	return out
