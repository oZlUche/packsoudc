## 猎手机制（069 伪 PVP）：难度清单里开它，一局里就有猎手。参数全在这里，数字不写死。
##
## `install` 造一个 [HunterSystem] 挂到 `run.hunters`（读档时用存档里的状态恢复）；幂等：装过了只刷新定义表。
class_name HunterMechanic
extends RunMechanic

## 用哪几种猎手（HunterDef 的 id）；几个猎手就按顺序轮着用
@export var hunter_ids: Array[StringName] = []
## 一局几个（没有按规模配时）
@export var default_count: int = 1
## 地图规模 id → 几个（作者：数量取决于地图规模）
@export var count_by_scale: Dictionary = {}
## 第几步之后出现（0 = 走第一步就出现）
@export var spawn_after_steps: int = 0
## 出现时离玩家至少多远（度量见 MapMetric）
@export var spawn_min_distance: float = 3.0
## 距离度量：steps（图上的步数）/ absolute（布局坐标，持有方注入）
@export var metric: StringName = &"steps"
## 段位（作者：只受步数影响）：第 k 段从第几步开始，非递减、第一项 0。猎手按段位定档（HunterDef.strength_by_bracket），木桩也按它分段
@export var bracket_steps: Array[int] = [0, 5, 10, 20]


## 走了这么多步在第几段（0 起）
func bracket_of(steps: int) -> int:
	var k := 0
	for i in bracket_steps.size():
		if steps >= bracket_steps[i]:
			k = i
	return k


static func bracket_of_steps(thresholds: Array[int], steps: int) -> int:
	var k := 0
	for i in thresholds.size():
		if steps >= thresholds[i]:
			k = i
	return k


func count_for(scale_id: StringName) -> int:
	return int(count_by_scale.get(String(scale_id), default_count))


func install(run: RunState) -> void:
	run.mechanic_tags[&"hunters"] = true
	if run.hunters != null:
		run.hunters.defs = run.hunter_defs
		run.hunters.setup(run, self, run.hunter_defs)
		return
	var sys := HunterSystem.new()
	sys.setup(run, self, run.hunter_defs)
	if not run.hunters_saved.is_empty():
		sys.restore(run.hunters_saved)
	run.hunters = sys


func describe() -> String:
	return "猎手 ×%d（%s）" % [default_count, "、".join(hunter_ids)] if not hunter_ids.is_empty() else "猎手（没配种类）"
