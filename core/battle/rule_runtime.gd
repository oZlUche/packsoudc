## 一条规则在战场上的实例：规则本体 + 它自己的持久状态。
##
## [member state] 由频率与消耗层读写（冷却进度、已命中次数、已用次数…）。
## 同一条 [AbilityRule] 资源可能被多件物品共用，所以状态**不能**存在规则资源上。
class_name RuleRuntime
extends RefCounted

var rule: AbilityRule
## 来源物品 uid；0 表示这条规则来自 buff 或套装
var source_uid: int = 0
## 规则来自 buff 时非空
var buff: BuffInstance = null
var state: Dictionary = {}


static func create(p_rule: AbilityRule, p_uid: int = 0, p_buff: BuffInstance = null) -> RuleRuntime:
	var rt := RuleRuntime.new()
	rt.rule = p_rule
	rt.source_uid = p_uid
	rt.buff = p_buff
	return rt
