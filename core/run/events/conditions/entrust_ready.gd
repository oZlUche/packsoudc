## 287：条件 —— 站在这个撤离点上能托付（免费、出口没关、托付还开着，[SafeModule]）。撤离点事件的「托付」选项用它，不满足就不显示
class_name EntrustReady
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.hooks != null and ctx.hooks.entrust_open(ctx.node)


func describe() -> String:
	return UiText.t("cond.not_met")
