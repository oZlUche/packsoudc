## 一条规则在战场上的实例：规则本体 + 它自己的持久状态。
##
## [member state] 由频率与消耗层读写（冷却进度、已命中次数、已用次数…）。
## 同一条 [AbilityRule] 资源可能被多件物品共用，所以状态**不能**存在规则资源上。
class_name RuleRuntime
extends RefCounted

var rule: AbilityRule
## 归属哪一方（0 / 1）。
##
## 存 int 而不是 CombatantRuntime 引用：单位持有规则，规则再反指单位就成了引用环，
## RefCounted 永不释放。派发时用 ctx.sides[owner_side] 取回。
var owner_side: int = 0

## 来源物品 uid；0 表示这条规则来自 buff 或套装
var source_uid: int = 0
## 规则来自 buff 时非空
var buff: BuffInstance = null
var state: Dictionary = {}

## 排序次序键，同刻并列时用它决定先后。
##
## 由 [CombatantRuntime] 在登记时写入，形如 side × 100000 + 登记序号，
## 因此顺序是「side 0 在前，各方内部按登记顺序」—— 与架构文档 4.7 一致。
## 没有它的话，同刻并列的先后会取决于堆的内部排布，同一局面可能产出不同结果。
var order: int = 0


static func create(
	p_rule: AbilityRule, p_uid: int = 0, p_buff: BuffInstance = null, p_side: int = 0
) -> RuleRuntime:
	var rt := RuleRuntime.new()
	rt.rule = p_rule
	rt.source_uid = p_uid
	rt.buff = p_buff
	rt.owner_side = p_side
	return rt
