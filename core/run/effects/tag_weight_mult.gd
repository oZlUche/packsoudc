## 256（马库斯「操练」）：带这些标签的道具重量按百分比改（−20 = 轻两成）。[RunState.carry_weight] 按件乘完求和再取整
## （[method ItemWeight.total_scaled]），面板的「负重」读数、负重档位、悬浮窗脚注的重量都跟着变
class_name TagWeightMult
extends RunEffect

@export var tags: Array[StringName] = []
@export var percent: int = 0


func modify(ctx: RunContext) -> void:
	if percent == 0 or tags.is_empty():
		return
	ctx.weight_pct.append({"tags": tags.duplicate(), "percent": percent})


func describe() -> String:
	return UiText.t("bonus.tag_weight") % [TagMods._tags_text(tags), "%+d%%" % percent]
