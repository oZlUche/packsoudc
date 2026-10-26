## 局内技能（作者定，报告 082）：角色带的技能，**被动常驻 + 可选的主动一击**。
##
## 072 把技能做成了「一局规则的效果构件」（侦察、潜行、逃跑），只有被动。作者补：技能可以在大地图上主动使用（马库斯的「突击」：
## 下次进入战斗先扣对方三成血），也有被动常驻生效（布鲁图斯：血量、体力、耐力更高）。所以技能是一个构件：
## - [member passive]：常驻的效果（[RunEffect] / [LootEffect]，和 buff、难度同一套），开局编进 RunContext；
## - 主动部分由子类给：[method is_active] 为真的才在地图屏上有按钮，[method activate] 做那件事（或立一面旗等下一场战斗），
##   次数（[member uses]，-1 = 不限）与冷却（[member cooldown_steps]，走几步）由 [RunSkills] 记账。
## 加一种技能 = 一个子类 + 注册表一行（RunRegistry.RUN_SKILLS）；角色文件里 "skills": [{"type": "assault", ...}]。数都是字段，不写死。
@abstract
class_name RunSkill
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 221 F4：别的语言的名字（{"en": …}），经 [Names] 取
@export var display_names: Dictionary = {}
@export_multiline var description: String = ""
## 221 F5: description in other languages, {"en": ...}
@export var descriptions: Dictionary = {}
## 255：选角色屏条目行左端的图标 —— `assets/ui/skills/` 下的文件名（不含扩展名）；空 = 用 id。文件不在就画通用纹样占位
@export var icon: String = ""
## 常驻的效果：一局规则（体力上限、逃跑、属性加成……）或掉落
@export var passive: Array[Effect] = []
## 136：战斗里常驻的规则（布鲁图斯「坚韧」：低血一次性护甲）。编译玩家时和套装 / buff 的规则一起挂到单位上
@export var rules: Array[AbilityRule] = []
## 主动使用的次数，-1 = 不限；被动技能不看它
@export var uses: int = -1
## 用一次之后要走几步才能再用；0 = 没有冷却
@export var cooldown_steps: int = 0
## 256（安德烈乌斯的偷袭）：每到一个休息点补几次，补不过 [member uses]；0 = 不补
@export var rest_recharge: int = 0
## 256：战前屏上给它一把键（166 的 [constant RunSkills.ACTIVE_HIDDEN] 对它不生效：选角色卡与说明也列它）
@export var show_prebattle: bool = false


## 有没有主动的一击（有 = 地图屏上有按钮）
func is_active() -> bool:
	return false


## 玩家看不看得见它（选角色卡、说明句、战前屏）：被动都看得见；主动的在 166 藏着，除非 [member show_prebattle]
func shown_to_player() -> bool:
	return not is_active() or not RunSkills.ACTIVE_HIDDEN or show_prebattle


## 136：地图右栏的按钮能不能直接按（脱身只在战前准备屏 / 猎手事件屏上用：地图上按钮灰着）
func map_usable() -> bool:
	return true


## 主动使用。返回空串 = 用了；否则是不能用的原因。[RunSkills] 已经查过次数与冷却，这里只做自己的事
func activate(_run: RunState) -> String:
	return UiText.t("skill.no_active")


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
	var tail := UiText.t("tip.list_sep").join(parts)
	return Names.of(self) + (UiText.t("skill.summary_tail") % tail if tail != "" else "")
