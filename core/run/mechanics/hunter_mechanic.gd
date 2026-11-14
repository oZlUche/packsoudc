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
## 320 A3：段内生命渐变，免得跨一步从打得过变成打不过。第 k 段刚进来时最大生命 × hp_from[k]，走到下一段的前一步 × hp_to[k]，
## 中间按步数线性；最后一段没有终点，用 [member hp_last_span] 步走完。没写的段 = 1（不改）
@export var hp_from: Array[float] = []
@export var hp_to: Array[float] = []
## 最后一段从 hp_from 走到 hp_to 用几步
@export var hp_last_span: int = 10


## 走了这么多步在第几段（0 起）
func bracket_of(steps: int) -> int:
	return bracket_of_steps(bracket_steps, steps)


static func bracket_of_steps(thresholds: Array[int], steps: int) -> int:
	var k := 0
	for i in thresholds.size():
		if steps >= thresholds[i]:
			k = i
	return k


## 走了这么多步时猎手的生命倍率（段内渐变，见 [member hp_from]）
func hp_for_steps(steps: int) -> float:
	var k := bracket_of(steps)
	var lo := hp_from[k] if k < hp_from.size() else 1.0
	if k >= hp_to.size():
		return lo
	var span := bracket_steps[k + 1] - 1 - bracket_steps[k] if k + 1 < bracket_steps.size() else hp_last_span
	if span <= 0:
		return lo
	return lerpf(lo, hp_to[k], clampf(float(steps - bracket_steps[k]) / float(span), 0.0, 1.0))


func count_for(scale_id: StringName) -> int:
	return int(count_by_scale.get(String(scale_id), default_count))


func install(run: RunState) -> void:
	if run.hunters != null:
		run.hunters.defs = run.hunter_defs
		run.hunters.setup(run, self, run.hunter_defs)
		return
	var sys := HunterSystem.new()
	sys.setup(run, self, run.hunter_defs)
	if not run.hunters_saved.is_empty():
		sys.restore(run.hunters_saved)
	run.hunters = sys
