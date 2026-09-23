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
	sys.sensed.connect(func(h: Hunter): run.hunter_sensed.emit(h))
	sys.changed.connect(func(): run.hunters_changed.emit())
	sys.player_expelled.connect(func(to: int): run.player_expelled.emit(to))


func describe() -> String:
	return "猎手 ×%d（%s）" % [default_count, "、".join(hunter_ids)] if not hunter_ids.is_empty() else "猎手（没配种类）"
