## 信仰道具在信力过了第 [member tier] 阶之后多出来的功能（作者定，报告 082）：属性修饰与规则，和道具本身的战斗定义同一套词汇。
## 写在道具上（[ItemDef.faith_bonuses]），[BattleCompiler.compile] 按传进来的「信仰 → 现在第几阶」决定并不并入。
class_name FaithBonus
extends Resource

## 第几阶起生效（1 = 过了第一道阈值）
@export var tier: int = 1
## 施加给这件道具的属性修饰
@export var mods: Array[StatModifier] = []
## 多出来的规则
@export var rules: Array[AbilityRule] = []
## 给界面的一句
@export var note: String = ""
