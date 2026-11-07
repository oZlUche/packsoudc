## 条件（194 §1）：这座休息点的铸炉还没用过（一座只能铸一次）。配 hide_when_locked，铸过了「铸炉」选项就藏起来。
## 286 §2.2：「铁炉」是砧 | 铸炉两栏 —— 两栏都用过了才算用过
class_name ForgeUnused
extends EventCondition


func check(ctx: EventContext) -> bool:
	return ctx != null and ctx.node != null and NodeEvents.hearth_open(ctx.node)


func describe() -> String:
	return UiText.t("forge.used")
