## 条件（几率、状态、资源、轴）：只检查、**不扣** —— 失败行为和消耗一致（跳过效果、冷却照走），所以和消耗同层
@abstract
class_name Condition
extends Cost


func pay(_ctx: RuleContext) -> void:
	pass


func is_condition() -> bool:
	return true
