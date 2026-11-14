## 320 A9（深层侵蚀）：道具实例上的侵蚀层数。层数记在 [member ItemInstance.state]（旧档没有 = 0），上限跟着层数一起记
## （第一次被侵蚀时写上，默认 [constant DEFAULT_LIMIT]）。到上限那一次就永久损毁：从容器里拿掉，不留残件、撤离不复活。
## 正常撤离只清带出来的幸存道具（[method clear_all]）；战败不清。移动、旋转、地上交换、买卖、存读档都跟着实例走，不会洗掉。
class_name ItemErosion
extends RefCounted

const KEY := "erosion"
const LIMIT_KEY := "erosion_limit"
const DEFAULT_LIMIT := 3


static func count(inst: ItemInstance) -> int:
	return int(inst.state.get(KEY, 0)) if inst != null else 0


static func limit(inst: ItemInstance) -> int:
	return int(inst.state.get(LIMIT_KEY, DEFAULT_LIMIT)) if inst != null else DEFAULT_LIMIT


## 这件能不能被侵蚀：包（包没了里面全散）、角色随身之物、券、特殊道具、内部道具不算；锁了、红武照样算
static func eligible(inst: ItemInstance) -> bool:
	if inst == null or inst.def == null or inst.def.is_bag or inst.is_pinned():
		return false
	for t in [ItemDef.SIGNATURE, ItemDef.TICKET, ItemDef.KEEPSAKE, ItemDef.TOKEN]:
		if inst.def.tags.has(t):
			return false
	return true


## 加一层。返回加完的层数；到了上限返回值 ≥ 上限，由调用方损毁
static func add(inst: ItemInstance, p_limit: int = DEFAULT_LIMIT) -> int:
	if not inst.state.has(LIMIT_KEY):
		inst.state[LIMIT_KEY] = maxi(1, p_limit)
	var n := count(inst) + 1
	inst.state[KEY] = n
	return n


static func is_full(inst: ItemInstance) -> bool:
	return count(inst) >= limit(inst)


## 清零（正常撤离时，带出来的幸存道具）
static func clear(inst: ItemInstance) -> void:
	if inst != null:
		inst.state.erase(KEY)
		inst.state.erase(LIMIT_KEY)


static func clear_all(list: Array) -> int:
	var n := 0
	for inst in list:
		if inst is ItemInstance and count(inst) > 0:
			clear(inst)
			n += 1
	return n


## 合成：成品继承所有消耗输入里最高的层数（不算一次新的侵蚀）。返回继承的层数
static func carry(out: ItemInstance, from: Array) -> int:
	var top := 0
	var cap := DEFAULT_LIMIT
	for inst in from:
		if inst is ItemInstance and count(inst) > top:
			top = count(inst)
			cap = limit(inst)
	if top > 0 and out != null:
		out.state[KEY] = top
		out.state[LIMIT_KEY] = cap
	return top


## 「侵蚀2/3：达到满值时损毁」（浮窗那一行）；没被侵蚀空串
static func line(inst: ItemInstance) -> String:
	var n := count(inst)
	return UiText.t("erosion.item_line") % [n, limit(inst)] if n > 0 else ""


## 这一局有没有道具侵蚀、进这个点会不会侵蚀一件（地图浮窗预告用；按现在的侵蚀算）
static func entry_warning(run: RunState, node: MapNode) -> String:
	var field: ErosionField = run.travel.erosion if run != null and run.travel != null else null
	if field == null or field.mechanic == null or node == null or not field.is_eroded(node):
		return ""
	for e in field.mechanic.effects:
		if e is ErodeItemLayer and (e as ErodeItemLayer).enabled and field.depth_of(node) >= (e as ErodeItemLayer).from_depth:
			return UiText.t("erosion.entry_warning")
	return ""
