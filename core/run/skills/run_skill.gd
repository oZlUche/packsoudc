## 局内技能（作者定，报告 082）：角色带的技能，**被动常驻 + 可选的主动一击**。
##
## 072 把技能做成了「一局规则的效果构件」（侦察、潜行、逃跑），只有被动。作者补：技能可以在大地图上主动使用（马库斯的「突击」：
## 下次进入战斗先扣对方三成血），也有被动常驻生效（布鲁图斯：血量、体力、耐力更高）。所以技能是一个构件：
## - [member passive]：常驻的效果（[RunEffect] / [LootEffect]，和 buff、难度同一套），开局编进 RunContext；
## - 主动部分由子类给：[method is_active] 为真的才在地图屏上有按钮，[method activate] 做那件事（或立一面旗等下一场战斗），
##   次数（[member uses]，-1 = 不限）与冷却（[member cooldown_steps]，走几步）由 [RunSkills] 记账。
## 加一种技能 = 一个子类 + 注册表一行（EffectRegistry.RUN_SKILLS）；角色文件里 "skills": [{"type": "assault", ...}]。数都是字段，不写死。
@abstract
class_name RunSkill
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 常驻的效果：一局规则（体力上限、逃跑、属性加成……）或掉落
@export var passive: Array[Effect] = []
## 主动使用的次数，-1 = 不限；被动技能不看它
@export var uses: int = -1
## 用一次之后要走几步才能再用；0 = 没有冷却
@export var cooldown_steps: int = 0


## 有没有主动的一击（有 = 地图屏上有按钮）
func is_active() -> bool:
	return false


## 主动使用。返回空串 = 用了；否则是不能用的原因。[RunSkills] 已经查过次数与冷却，这里只做自己的事
func activate(_run: RunState) -> String:
	return "这个技能没有主动效果"


## 立了旗等下一场战斗的技能：开打前改双方的战斗单位（[RunSkills.prepare_battle] 调，用完旗子撤）
func prepare_battle(_me: CombatantSpec, _enemy: CombatantSpec) -> void:
	pass


## 主动的那一击有没有「等下一场战斗」的旗子
func arms_battle() -> bool:
	return false


func run_effects() -> Array[RunEffect]:
	var out: Array[RunEffect] = []
	for e in passive:
		if e is RunEffect:
			out.append(e)
	return out


func loot_effects() -> Array[LootEffect]:
	var out: Array[LootEffect] = []
	for e in passive:
		if e is LootEffect:
			out.append(e)
	return out


## 主动部分的一句话（子类给）；被动的由 [method summary] 拼
func describe() -> String:
	return ""


## 给开局屏与地图屏：名字 + 主动说明 + 被动各一句
func summary() -> String:
	var parts: Array[String] = []
	if describe() != "":
		parts.append(describe())
	for e in passive:
		if e != null and e.has_method("describe") and String(e.call("describe")) != "":
			parts.append(String(e.call("describe")))
	var tail := "、".join(parts)
	return display_name + ("（" + tail + "）" if tail != "" else "")
