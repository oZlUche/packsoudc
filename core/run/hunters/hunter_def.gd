## 一种猎手（069 伪 PVP）：地图上移动的单位，不和节点互动，距离够近就开打。**一个等级一份文件**，数字全不写死。
##
## 强度不在这里：开打那一刻按当时的探索度现造（[EnemyPlacer]，和随机点、搜索遭遇同一条路），
## 只能指定从哪个池抽、按哪条强度规则算。行动逻辑与战败后果是构件。
## 走内容管线：`data/authoring/hunters/*.json` → `data/hunters/*.tres`，排在敌人池之后。
class_name HunterDef
extends Resource

enum Visibility { HIDDEN, VISIBLE, NEAR }

## 只写了 loss_outcomes 的旧定义合成的那一档叫这个
const LEGACY_OPTION := &"default"

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
## 134 之前的写法：输了之后按顺序发生的事（只有一档）。写了 [member loss_options] 就不看它；没写当作只有这一档
@export var loss_outcomes: Array[HunterLossOutcome] = []
## 134：这种猎手可能给的战败结果档（击退 / 驱逐……）。生成时按 [member loss_pick] 选定一档，跟着那只猎手存档
@export var loss_options: Array[HunterLossOption] = []
## 134：怎么选档。null = 按权重随机
@export var loss_pick: HunterLossPick = null
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

var _legacy: HunterLossOption = null


## 这个段位该给哪一档；表空返回 -1（让调用方走规则）
func strength_for_bracket(bracket: int) -> int:
	if strength_by_bracket.is_empty():
		return -1
	return strength_by_bracket[clampi(bracket, 0, strength_by_bracket.size() - 1)]


## 134：可能的结果档。没写 loss_options 的旧定义当作只有一档（就是 loss_outcomes）
func options() -> Array[HunterLossOption]:
	if not loss_options.is_empty():
		return loss_options
	if _legacy == null:
		_legacy = HunterLossOption.new()
		_legacy.id = LEGACY_OPTION
		_legacy.outcomes = loss_outcomes
	return [_legacy] as Array[HunterLossOption]


## 按档名找；找不到（旧存档没有档名、档被删了）按第一档
func option_by_id(id: StringName) -> HunterLossOption:
	var all := options()
	for o in all:
		if o != null and (o as HunterLossOption).id == id:
			return o
	return all[0] if not all.is_empty() else null


## 生成时选一档，返回档名
func pick_option(sys: HunterSystem) -> StringName:
	var all := options()
	var picker: HunterLossPick = loss_pick if loss_pick != null else LossPickRandom.new()
	var i := picker.pick(all, sys)
	return (all[i] as HunterLossOption).id if i >= 0 and i < all.size() and all[i] != null else &""


func can_flee() -> bool:
	return flee_chance > 0.0


func summary() -> String:
	var parts: Array[String] = []
	parts.append(behavior.describe() if behavior != null and behavior.describe() != "" else "不动")
	parts.append("感知 %.0f" % sense_range)
	parts.append("速度 %d" % speed)
	var all := options()
	if all.size() == 1:
		var only := (all[0] as HunterLossOption).summary() if all[0] != null else ""
		if only != "":
			parts.append(only)
	elif all.size() > 1:
		var names: Array[String] = []
		for o in all:
			if o != null:
				names.append((o as HunterLossOption).display_name if (o as HunterLossOption).display_name != "" else String((o as HunterLossOption).id))
		parts.append("输了：%s 之一" % " / ".join(names))
	return "　".join(parts)
