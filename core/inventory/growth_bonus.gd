## 207：生长到某一阶时「有可能获得的额外效果」—— [member GrowthStage.bonus_pool] 里的一条。
## 形状同信仰加成（[FaithBonus]）的效果那半：属性修饰 + 规则（无 costs），外加一句作者补充
class_name GrowthBonus
extends Resource

## 施加给这件道具的属性修饰
@export var mods: Array[StatModifier] = []
## 多出来的规则
@export var rules: Array[AbilityRule] = []
## 给界面的补充一句（[TextTemplate] 模板）
@export var note: String = ""


## 给界面的一句：属性修饰 + 规则 + 作者补充
func effect_text() -> String:
	return GrowthStage.effect_text_of(mods, rules, note)
