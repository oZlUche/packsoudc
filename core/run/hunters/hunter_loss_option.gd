## 一个战败结果档（134）：猎手输了之后的一整套后果，生成猎手时按 [HunterLossPick] 选定一档、跟着存档。
## 同一种猎手可以有好几档（击退 / 驱逐……），每只生成时各定各的。加一种结果 = 写一个 [HunterLossOutcome] 子类、在某个定义里加一档
class_name HunterLossOption
extends Resource

## 档名，如 `repel`（击退）、`expel`（驱逐）；一个定义里不能重
@export var id: StringName = &""
## 给玩家看的名字（「击退」）
@export var display_name: String = ""
## 221 F5：别的语言的名字
@export var display_names: Dictionary = {}
## 随机选时的权重（[LossPickRandom]）
@export var weight: float = 1.0
## 输了之后按顺序发生的事
@export var outcomes: Array[HunterLossOutcome] = []


## 给玩家看的一句：「击退：它退 2 步、歇 2 步」
func summary() -> String:
	var parts: Array[String] = []
	for o in outcomes:
		var lo := o as HunterLossOutcome
		if lo != null and lo.describe() != "":
			parts.append(lo.describe())
	var name := Names.of(self) if display_name != "" else String(id)
	if parts.is_empty():
		return name
	return UiText.t("hunter.loss_named") % [name, UiText.t("log.comma_sep").join(parts)] if name != "" else UiText.t("log.comma_sep").join(parts)
