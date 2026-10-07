## 一件物品的编译结果：结算后的属性快照 + 它的规则表。
##
## 原名 Ability。改名是因为它承载的已不止「一个能力」——
## 一件物品可以有多条规则（平时按冷却出手、受击时反击、开局加护盾）。
class_name CompiledItem
extends RefCounted

var source_uid: int = 0
var def_id: StringName = &""
## 132：道具的标签（`on_item_fired.source_tags` 按它筛出手的是哪类件）
var tags: Array[StringName] = []
## 结算后的属性快照。战斗中不再回头读背包。
var stats: StatSet = null
var rules: Array[AbilityRule] = []

## 通过增益／受益格与本物品连结的其他物品 uid，升序去重。
##
## 本作没有「主武器」这种设定，所以「跟着某件东西一起触发」只能靠邻接连结来表达：
## 谁占着我的增益格、谁给我点亮了受益格，编译期就已经知道，
## [OnItemFired] 的 LINKED 来源直接查这张表。
##
## 在编译期算好而不是运行时查棋盘：战斗中背包是冻结的（4.1），
## 而且这样战斗层完全不需要认识 [GridInventory]。
var linked_uids: Array[int] = []

## 108（作者定）：**附加规则**的来源 —— 别人挂到我身上的规则（邻居的增益规则、信仰附魔），与 [member rules] 的下标对齐；
## 自己写的规则没有条目。`{"rule_index": int, "origin": StringName}`，origin = 道具 def id（邻居给的）
## 或 `faith:<id>`（信仰给的）。规则本身仍平铺在 [member rules] 里，战斗层不用认识它；只给悬浮窗写「← 毒箭」用
var attached: Array[Dictionary] = []


func is_active() -> bool:
	return not rules.is_empty()


## 粗略 DPS，供玩家拖动物品时实时预估。
## 不考虑触发顺序、消耗与状态效果，只做手感参考。[param with_stats] 给了就按那份属性算（[CombatantSpec] 把开战即上身的
## buff 并进去再问，087：护符的「血怒」这类开战增伤要能在统计里看见）
func estimated_dps(with_stats: StatSet = null) -> float:
	var use := with_stats if with_stats != null else stats
	var total := 0.0
	for rule in rules:
		var r := rule as AbilityRule
		if r.cadence == null:
			continue
		var hz := r.cadence.estimated_hz(use)
		if hz <= 0.0:
			continue
		for effect in r.effects:
			total += hz * (effect as CombatEffect).estimated_damage(use)
	return total


func _to_string() -> String:
	return "CompiledItem(%s uid=%d %d 条规则 约 %.1f DPS)" % [
		def_id, source_uid, rules.size(), estimated_dps()
	]
