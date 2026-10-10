## 151（作者定）：战斗力估算的系数表 —— 「每格基准多少 DPS」「一点治疗抵几点伤害」「假定一秒挨几下」……
##
## 全是**占位**，作者改 `data/authoring/balance/power_weights.json`（[constant PATH]）里的数，不改代码；文件里没写的项用这里的默认。
## 估算器（[PowerEstimate]）与各构件的估值方法（[method CombatEffect.estimated_value]、[method Trigger.estimated_rate]、
## [method Cost.estimated_factor]）只从这里取数。放在战斗层是因为构件的估值方法要认识它；读文件的只有 [method load_from]
class_name PowerWeights
extends RefCounted

const PATH := "res://data/authoring/balance/power_weights.json"

## 每一项的默认值（键 = 文件里的键 = 成员名）。加一项 = 这里一行 + 一个同名成员
const DEFAULTS := {
	"horizon_sec": 30.0,
	"persist_share": 0.3,
	"per_cell_dps": 2.0,
	"default_cooldown": 2.0,
	"stamina_per_cell": 2.0,
	"heal_weight": 0.5,
	"stamina_weight": 0.25,
	"assumed_hp": 100.0,
	"opponent_dps": 10.0,
	"hit_rate": 1.0,
	"crit_rate": 0.05,
	"neighbor_hz": 0.5,
	"low_hp_share": 0.3,
	"threshold_share": 0.5,
	"status_applied_rate": 0.3,
	"status_removed_rate": 0.2,
	"stamina_regen": 4.0,
	"stack_cost_factor": 0.5,
	"condition_factor": 0.6,
	"assumed_stacks": 2.0,
	"unknown_buff_value": 1.0,
	"weight_base": 48.0,
	"weight_floor": 0.6,
	"tiers": [0.9, 1.35, 1.9, 2.8],
	"value_band": [0.8, 0.4],
}

## 估算视野 H：一场打多久（秒）。持续类效果按 H 内能跑多久算
var horizon_sec: float = 30.0
## 永续的东西（可叠层的 buff、轴）平均还能起作用的时间占 H 的几成（中途上的，后半场才有）
var persist_share: float = 0.3
## 每格基准 DPS：默认战斗力 = 它 × 格数；推荐稀有度的预算比也除以它
var per_cell_dps: float = 2.0
## 新建武器预填的冷却（秒）；伤害按默认战斗力反算
var default_cooldown: float = 2.0
## 新建武器预填的每次耐力消耗 = 它 × 格数
var stamina_per_cell: float = 2.0
## 一点治疗 / 护盾抵几点伤害
var heal_weight: float = 0.5
## 一点耐力（回复、省下的消耗）抵几点伤害
var stamina_weight: float = 0.25
## 假定对手生命（按最大 / 当前 / 已损失生命比例的伤害按它算）
var assumed_hp: float = 100.0
## 假定对手 DPS（反伤、对手身上增益的价值按它算）
var opponent_dps: float = 10.0
## 假定一秒挨几下直接攻击（受击扳机、防护、反伤按它算）
var hit_rate: float = 1.0
## 假定暴击率（只认暴击的扳机）
var crit_rate: float = 0.05
## 假定邻居 / 别的件一秒出手几次（听别人出手的扳机）
var neighbor_hz: float = 0.5
## 「低血强化」在一场里有几成时间生效
var low_hp_share: float = 0.3
## 「到了多少层 / 血量低于多少」这类门槛扳机没法从本件算出来时，满足的时间占比
var threshold_share: float = 0.5
## 「施加了某 buff 时」不是本件施加的，假定一秒几次
var status_applied_rate: float = 0.3
## 「移除了某 buff 时」假定一秒几次
var status_removed_rate: float = 0.2
## 耐力回复基线（每秒），耐力消耗按它算能持续几成
var stamina_regen: float = 4.0
## 吃层的消耗（轴、buff 层）打几折（吃掉的层本身有价值）
var stack_cost_factor: float = 0.5
## 状态 / 资源 / 轴条件满足的概率（取反 = 一减它）
var condition_factor: float = 0.6
## 按层数算的效果没有别的线索时，假定几层（清光全部也按它）
var assumed_stacks: float = 2.0
## 查不到定义的 buff 每层每秒值多少
var unknown_buff_value: float = 1.0
## 负重基准（马库斯的负重上限，149）：折扣 = max(下限, 1 − 重量 ÷ 它)
var weight_base: float = 48.0
var weight_floor: float = 0.6
## 推荐稀有度的预算比阈值：低于第 i 个 = 第 i 档（普通、优良、稀有、史诗），其余传说；神话不推荐
var tiers: Array[float] = [0.9, 1.35, 1.9, 2.8]
## 推荐价值 = 每格价 × 格数 × (band[0] + band[1] × 档内位置)
var value_band: Array[float] = [0.8, 0.4]


## 读系数表；文件没有、读不了、缺项都用默认。[param problems] 收认不出的键与类型不对的项
static func load_from(path: String = PATH, problems: Array[String] = []) -> PowerWeights:
	var w := PowerWeights.new()
	if not FileAccess.file_exists(path):
		return w
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		problems.append("%s 读不了，用默认系数" % path)
		return w
	w.apply(parsed, problems)
	return w


## 把一份字典里的项盖到默认值上
func apply(d: Dictionary, problems: Array[String] = []) -> void:
	for key in d:
		var k := String(key)
		if k.begins_with("_"):     # 「_说明」这类注释键
			continue
		if not DEFAULTS.has(k):
			problems.append("没有这个系数 '%s'" % k)
			continue
		var v: Variant = d[key]
		if DEFAULTS[k] is Array:
			if not (v is Array) or (v as Array).size() != (DEFAULTS[k] as Array).size():
				problems.append("'%s' 得是 %d 个数" % [k, (DEFAULTS[k] as Array).size()])
				continue
			var arr: Array[float] = []
			for x in v:
				arr.append(float(x))
			set(k, arr)
		elif v is float or v is int:
			set(k, float(v))
		else:
			problems.append("'%s' 得是数" % k)


## 一个效果平均能起作用多久（秒）：永续 = H × 永续占比，有时长 = min(时长, H)
func expected_duration(seconds: float, permanent: bool) -> float:
	return horizon_sec * persist_share if permanent else minf(seconds, horizon_sec)


func to_dict() -> Dictionary:
	var out := {}
	for k in DEFAULTS:
		out[k] = get(k)
	return out
