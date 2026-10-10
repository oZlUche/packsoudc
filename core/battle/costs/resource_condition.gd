## 资源条件（132）：出手时检查某种资源在某个范围里才放行，**不扣**。和 [StatusCondition] 同族的条件型消耗。
##
## 百分比按上限算（0..100），绝对值按点数；四个界哪个填了（≥ 0）就检查哪个，全部满足才过。
## 「生命高于 70% 时」「耐力不到一半时」用它。导入器要求至少填一个界
class_name ResourceCondition
extends Cost

@export var resource_key: StringName = &"hp"
## 看自己（true）还是对手（false）
@export var on_self: bool = true
## 至少占上限的百分之几（−1 = 不限）
@export var min_percent: int = -1
## 至多占上限的百分之几（−1 = 不限）
@export var max_percent: int = -1
## 至少几点（−1 = 不限）
@export var absolute_min: float = -1.0
## 至多几点（−1 = 不限）
@export var absolute_max: float = -1.0
## 取反
@export var negate: bool = false


func has_bounds() -> bool:
	return min_percent >= 0 or max_percent >= 0 or absolute_min >= 0.0 or absolute_max >= 0.0


func can_pay(ctx: RuleContext) -> bool:
	var who := ctx.side_of(on_self)
	if who == null or not who.resources.has(resource_key):
		return negate
	var cur := who.resources.current(resource_key)
	var mx := who.resources.maximum(resource_key)
	var ok := true
	# 比百分比用整数交叉相乘，免得定点除法的舍入在边界上抖
	if min_percent >= 0 and cur * 100 < mx * min_percent:
		ok = false
	if max_percent >= 0 and cur * 100 > mx * max_percent:
		ok = false
	if absolute_min >= 0.0 and cur < StatMath.from_float(absolute_min):
		ok = false
	if absolute_max >= 0.0 and cur > StatMath.from_float(absolute_max):
		ok = false
	return ok != negate


func pay(_ctx: RuleContext) -> void:
	pass


## 142：「若你的生命不低于 70%」「若对手的耐力不到 50%」；几个界都填了就用「、」连起来
func describe() -> String:
	var who := "你" if on_self else "对手"
	var res := Glossary.resource_name(resource_key)
	var bits: Array[String] = []
	if min_percent >= 0:
		bits.append("不低于 %d%%" % min_percent)
	if max_percent >= 0:
		bits.append("不高于 %d%%" % max_percent)
	if absolute_min >= 0.0:
		bits.append("不低于 %s 点" % TextTemplate.num(absolute_min))
	if absolute_max >= 0.0:
		bits.append("不高于 %s 点" % TextTemplate.num(absolute_max))
	var line := "若%s的%s%s" % [who, res, "、".join(bits)]
	return ("并非（%s）" % line) if negate else line


## 151：条件满足的概率（取反 = 一减它）
func estimated_factor(ctx: PowerContext, _rate: float) -> float:
	var p := ctx.weights.condition_factor
	return 1.0 - p if negate else p


func is_condition() -> bool:
	return true
