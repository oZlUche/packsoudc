## 一种猎手（069 伪 PVP）：地图上移动的单位，不和节点互动，距离够近就开打。**一个等级一份文件**，数字全不写死。
##
## 强度不在这里：开打那一刻按当时的探索度现造（[EnemyPlacer]，和随机点、搜索遭遇同一条路），
## 只能指定从哪个池抽、按哪条强度规则算。行动逻辑与战败后果是构件。
## 走内容管线：`data/authoring/hunters/*.json` → `data/hunters/*.tres`，排在敌人池之后。
class_name HunterDef
extends Resource

enum Visibility { HIDDEN, VISIBLE, NEAR }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var level: int = 1
## 地图上看不看得见：一直看不见 / 一直看得见 / 进了 near_range 才看得见
@export var visibility: Visibility = Visibility.NEAR
@export var near_range: float = 2.0
## 感知玩家的距离（度量见 MapMetric）；角色技能按上下文的 sense_mult 乘
@export var sense_range: float = 3.0
## 每个玩家步走几小步
@export var speed: int = 1
## 距离 ≤ 它就开打（0 = 同一个点）
@export var engage_range: float = 0.0
## 领地半径（离出生点），≤ 0 = 整张图
@export var territory_radius: float = 4.0
@export var behavior: HunterBehavior = null
## 输了之后按顺序发生的事
@export var loss_outcomes: Array[HunterLossOutcome] = []
## 掉落率倍数（作者：模板和普通敌人一样，掉落率更高）
@export var drop_mult: float = 1.5
## 逃跑：基础成功率（0 = 逃不掉，事件屏不给这个选项）、失败扣几点体力、逃掉之后它歇几步
@export var flee_chance: float = 0.5
@export var flee_fail_vitality: int = 1
## 088：输给这个猎手扣多少体力。-1 = 按节点规则的 loss_cost.hunter；0 = 不扣；-2 = 必死；大于 0 = 扣那么多。战败后果构件另算
@export var loss_cost: int = -1
@export var flee_cooldown: int = 2
## 从哪个敌人池抽（空 = 这一章的池）、按哪条强度规则（null = 池自己的）
@export var enemy_pool: StringName = &""
@export var strength_rule: StrengthRule = null
## 按玩家的段位定档（作者：猎手的实际配置随玩家当前段位变，段位只受步数影响）：下标 = 段位（[HunterMechanic.bracket_steps] 划的），
## 值 = 池里的档位；超出表长按最后一档。空 = 退回强度规则
@export var strength_by_bracket: Array[int] = []
## 占位：和节点的互动（作者：保留选项）。现在恒为不互动
@export var node_interaction: StringName = &"none"


## 这个段位该给哪一档；表空返回 -1（让调用方走规则）
func strength_for_bracket(bracket: int) -> int:
	if strength_by_bracket.is_empty():
		return -1
	return strength_by_bracket[clampi(bracket, 0, strength_by_bracket.size() - 1)]


func can_flee() -> bool:
	return flee_chance > 0.0


func summary() -> String:
	var parts: Array[String] = []
	parts.append(behavior.describe() if behavior != null and behavior.describe() != "" else "不动")
	parts.append("感知 %.0f" % sense_range)
	parts.append("速度 %d" % speed)
	for o in loss_outcomes:
		var lo := o as HunterLossOutcome
		if lo != null and lo.describe() != "":
			parts.append(lo.describe())
	return "　".join(parts)
