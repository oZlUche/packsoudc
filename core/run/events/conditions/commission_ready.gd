## 336（阵营与委托 W1）：条件 —— 站在这个撤离点上能做 [member action]（`inspect` 查验 / `deliver` 交信）：带着要查验的委托、这处还没查过；
## 或者身上有任务信、这是开着的免费撤离点（[CommissionModule]）。撤离点事件的两个选项用它，不满足就不显示
class_name CommissionReady
extends EventCondition

@export var action: StringName = &"inspect"


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.hooks != null and ctx.hooks.commission_can(action, ctx.node)


func describe() -> String:
	return UiText.t("cond.not_met")
