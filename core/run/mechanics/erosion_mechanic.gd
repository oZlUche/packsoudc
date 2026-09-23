## 侵蚀（5.7，第 7 阶段的本体还没做；069 把它从「每局都有」改成「某档难度开的机制」）。
##
## 现在是**空壳占位**：只在一局上留一个记号（`run.mechanic_tags`），`MapTravel.erosion` 仍是 null。
## 本体落地时在这里造 `ErosionField` / `ErosionSchedule` 接到 `run.travel.erosion`，参数就是下面这几个字段。
class_name ErosionMechanic
extends RunMechanic

## 每走一步侵蚀推进多少（占位）
@export var rate: float = 1.0
## 从第几档侵蚀带开始损坏背包物品（占位，6.4）
@export var damage_band: int = 2


func install(run: RunState) -> void:
	run.mechanic_tags[&"erosion"] = true


func describe() -> String:
	return "侵蚀（占位）：每步 %.1f，第 %d 带起损坏物品" % [rate, damage_band]
