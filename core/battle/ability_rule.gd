## 一条完整规则：什么时候 · 多久一次 · 付什么代价 · 做什么（架构文档 4.4）。
##
## 物品与 buff 都持有 [Array] 形式的规则表，一条规则可以有多个效果 ——
## 它们按声明顺序执行且**共用同一次消耗**：
## 「付一次耐力，同时造成伤害并施加灼烧」是一条规则两个效果，不是两条规则。
class_name AbilityRule
extends Resource

@export var trigger: Trigger
@export var cadence: Cadence
## 可为空。非武器道具通常没有消耗，但检查环节一律保留 ——
## 后期必然出现「消耗 N 层某增益才能触发」的效果。
@export var costs: Array[Cost] = []
@export var effects: Array[Effect] = []


func is_valid() -> bool:
	return trigger != null and cadence != null and not effects.is_empty()
