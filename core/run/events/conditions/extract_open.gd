## 反馈 11-21：条件 —— 站着的这个撤离点还没被倒计时关掉（[CountdownModule]）。撤离点事件的「撤离」选项用它，关了就灰掉、写明已关闭
class_name ExtractOpen
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx != null and (ctx.hooks == null or not ctx.hooks.extract_closed(ctx.node))


func describe() -> String:
	return UiText.t("cond.extract_closed")
