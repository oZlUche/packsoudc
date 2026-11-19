## 信仰的激活规则（信仰重构 A，2026-11-19 交接方案 §2；取代 8-4 的「最后置入的信物说了算」）：
##
## 玩家**显式选择**奉哪位神（`selected`，按神 id 存，不按某件信物的 uid）；**有效信仰**（`effective`）是纯查询：
## 选了、且棋盘上有这位神的有效信物（[method ItemDef.is_anchor]、没标不参战）才算联系正常。三态：
## [codeblock]
## 不奉神    selected 为空                    → 有效信仰为空
## 联系正常  selected 有效 + 棋盘上有它的信物   → 有效信仰 = selected
## 联系中断  selected 有效 + 棋盘上没有它的信物 → 有效信仰为空（不自动回退到别的神）
## [endcodeblock]
## 拾取、移动、旋转、整理、交易、合成都**不改** selected；同神的几件信物只维持同一份联系。
##
## 别的信仰的道具**休眠**：编译战斗单位时跳过它的战斗数据与邻接，套装也不计它（占格照占、价值照算）。
## 无信仰之物（不带 `faith` 标签）在任何信仰下都能用。
##
## 101 第 5 刀：这条规则**只看容器与标签**（[FaithTags]），一个字都不认具体的神，所以它住在道具层。
## 选择由 [RunState] 持有，镜像到棋盘的元数据 [constant SELECTED_META] 上（[method GridInventory.select_faith]），
## 这样只拿着棋盘的界面、套装（[SetTracker]）都读同一份；编译器不扫棋盘，显式收 [member CompileInput.faith]。
## 全是静态函数，不持有状态。
class_name FaithState
extends RefCounted

## 棋盘上记着的玩家选择（信仰对象标签 `faith:xxx`；空 = 不奉神）。不进棋盘存档，由 [RunState] 每次接上
const SELECTED_META := &"faith_selected"

## 联系状态（[method connection]）
const NONE := &"none"           # 不奉神
const OK := &"ok"               # 联系正常
const BENCHED := &"benched"     # 联系中断：这位神的信物都标了不参战
const MISSING := &"missing"     # 联系中断：棋盘上没有这位神的信物


## 这件在棋盘上能不能维持联系：是信物、没标不参战
static func is_live_anchor(inst: ItemInstance) -> bool:
	return inst != null and inst.def != null and inst.def.is_anchor() and not inst.is_benched()


## 棋盘上记着的选择（信仰对象标签）；没选 = 空
static func selected_tag(container: ItemContainer) -> StringName:
	if container == null:
		return &""
	return StringName(String(container.get_meta(SELECTED_META, "")))


## 选的这位神（标签）现在的联系状态（[constant NONE] / [constant OK] / [constant BENCHED] / [constant MISSING]）
static func connection(container: ItemContainer, tag: StringName) -> StringName:
	if tag == &"":
		return NONE
	if container == null:
		return MISSING
	var benched := false
	for raw in container.items():
		var inst := raw as ItemInstance
		if inst == null or inst.def == null or not inst.def.is_anchor() or inst.def.faith_tag() != tag:
			continue
		if not inst.is_benched():
			return OK
		benched = true
	return BENCHED if benched else MISSING


## 棋盘上的有效信仰（标签）：选了且联系正常；否则空
static func active_tag(container: ItemContainer) -> StringName:
	var tag := selected_tag(container)
	return tag if connection(container, tag) == OK else &""


## 有效信仰的 id（`brute`）；没有返回空
static func active_id(container: ItemContainer) -> StringName:
	return FaithTags.id_of_tag(active_tag(container))


## 只拿着一块棋盘的读者（界面、套装、悬浮窗的编译）用：记着玩家选择的棋盘（[constant SELECTED_META]）按选择 → 有效信仰；
## 没记的是组装出来的棋盘（敌人、台架）→ [method assembled_tag]。玩家的棋盘由 [RunState] / 开局屏一开始就记上（空也记）
static func board_tag(container: ItemContainer) -> StringName:
	if container == null:
		return &""
	return active_tag(container) if container.has_meta(SELECTED_META) else assembled_tag(container)


## 棋盘上有有效信物的那几位神（标签，升序）—— 「可以奉为主信仰」的候选
static func anchor_tags(container: ItemContainer) -> Array[StringName]:
	var out: Array[StringName] = []
	if container == null:
		return out
	for raw in container.items():
		var inst := raw as ItemInstance
		if is_live_anchor(inst) and not out.has(inst.def.faith_tag()):
			out.append(inst.def.faith_tag())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))     # 按字面排（StringName 自己的序不是字面序）
	return out


## 组装出来的棋盘（敌人 kit、台架、测试）的信仰：信物都是同一位神就是祂（[EnemyPlacer] 一个敌人只信一个神）；
## 几位神混着（理论上不该有）取标签最小的那位 —— 固定、和遍历与置入先后无关。没有信物 = 空。
## **不用于玩家**：玩家的信仰只来自显式选择
static func assembled_tag(container: ItemContainer) -> StringName:
	var tags := anchor_tags(container)
	return tags[0] if not tags.is_empty() else &""


## 旧规则（8-4）：棋盘上最后置入的那件信物（`placed_seq` 最大，平局 uid 大的；不参战的不算）。
## **只给存档迁移用**（[RunState] 读没有 `faith_selection` 的旧档时推一次 selected）；正式路径不准调
static func legacy_last_placed_tag(container: ItemContainer) -> StringName:
	if container == null:
		return &""
	var best: ItemInstance = null
	for raw in container.items():
		var inst := raw as ItemInstance
		if not is_live_anchor(inst):
			continue
		if best == null or inst.placed_seq > best.placed_seq or (inst.placed_seq == best.placed_seq and inst.uid > best.uid):
			best = inst
	return best.def.faith_tag() if best != null else &""


## 这件东西在这个有效信仰下是不是休眠的：有信仰、且不是有效的那个（有效信仰为空 = 所有信仰道具都休眠）
static func is_dormant(def: ItemDef, active: StringName) -> bool:
	return def != null and def.has_faith() and def.faith_tag() != active


## 信仰重构 B（交接方案 §4「失去赐福的普通剑仍是剑」）：普通道具派生的赐福版（[method ItemDef.is_blessed]）休眠时
## 只停神力层（[member ItemDef.faith_bonuses]），**基础层照常**：原物品的属性、规则、邻接、套装、生长都在。
## 手写的信仰道具（信物、赐福的长弓这类）没有可分离的基础层，照 087 的老规矩休眠
static func keeps_base_layer(def: ItemDef) -> bool:
	return def != null and def.is_blessed()


## 这件在这个有效信仰下是不是**整件**休眠（邻接、套装、生长都不算）：休眠、且不是带基础层的派生赐福版
static func is_inert(def: ItemDef, active: StringName) -> bool:
	return is_dormant(def, active) and not keeps_base_layer(def)


## 087（作者定）：休眠的这件还留着通用效果没有 —— 有战斗定义、且 [member ItemDef.dormant_keeps_combat] 开着。
## 留着 = 编译时仍参战（基础属性 + 自己的规则 + 包体加成），只丢信力加成、邻接、套装；不留 = 彻底不参战
static func keeps_combat_when_dormant(def: ItemDef) -> bool:
	return def != null and def.combat != null and def.dormant_keeps_combat


## 棋盘上整件休眠的那些 uid，升序（按 [method board_tag]；派生赐福版只停神力层，不在里面）
static func dormant_uids(container: ItemContainer) -> Array[int]:
	var out: Array[int] = []
	if container == null:
		return out
	var active := board_tag(container)
	for raw in container.items():
		var inst := raw as ItemInstance
		if inst != null and is_inert(inst.def, active):
			out.append(inst.uid)
	out.sort()
	return out
