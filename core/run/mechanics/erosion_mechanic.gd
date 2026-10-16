## 侵蚀机制（5.7 的本体，报告 075）：难度清单里开它，一局里地图就逐层向内被侵蚀。时间表与效果清单都在这里，数字不写死。
##
## 作者：侵蚀的各种效果都要能开关、能调（是否启用、在哪个阶段启用、触发概率）—— 效果是构件（[ErosionEffect]），每个自带四道门。
## `install` 造一个 [ErosionField] 接到 `run.travel.erosion`（读档时用存档里的状态恢复）；幂等。信号由界面直接接在它身上（140 R-23）。
class_name ErosionMechanic
extends RunMechanic

## 第一次侵蚀发生在第几个行动点
@export var first_at_action: int = 18
## 之后每隔多少行动推进一层
@export var interval_actions: int = 12
## 预警提前量（行动点），必须 > 0（5.7：没有预警的时间压力是随机惩罚）
@export var warn_lead_actions: int = 4
## 在被侵蚀的点结算时依次过门的效果
@export var effects: Array[ErosionEffect] = []


func install(run: RunState) -> void:
	run.mechanic_tags[&"erosion"] = true
	if run.travel == null:
		return
	if run.travel.erosion != null:
		run.travel.erosion.mechanic = self
		return
	var field := ErosionField.new()
	field.setup(run, self)
	if not run.erosion_saved.is_empty():
		field.restore(run.erosion_saved)
	run.travel.erosion = field


func describe() -> String:
	var parts: Array[String] = []
	parts.append("侵蚀：第 %d 步起、每 %d 步推进一层、提前 %d 步预警" % [first_at_action, interval_actions, warn_lead_actions])
	for e in effects:
		var effect := e as ErosionEffect
		if effect != null and effect.describe() != "":
			parts.append(effect.describe())
	return "　".join(parts)
