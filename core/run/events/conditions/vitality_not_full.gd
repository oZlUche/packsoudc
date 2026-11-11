## 条件：体力还没满（事件方案 2026-11-11 E04）—— 满体力时「花钱 / 花时间回体力」的选项灰掉，免得收了钱回 0 点
class_name VitalityNotFull
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx.vitality != null and ctx.vitality.current < ctx.vitality.maximum


func describe() -> String:
	return UiText.t("cond.vitality_full")
