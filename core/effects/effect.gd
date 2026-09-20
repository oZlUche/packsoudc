## 一切效果的根。**道具与套装共用同一套效果词汇。**
##
## 早先分成 `Effect`（战斗）与 `SetEffect`（套装）两棵树，结果是同一个概念存在两遍，
## 而且战利品效果被锁死在套装上 —— 「这把刀让敌人多掉一件东西」这种完全合理的道具
## 反而写不出来。现在统一到一棵树，按作用域分支。
##
## [codeblock]
## Effect
##   CombatEffect   战斗内，依赖扳机
##   LootEffect     战利品，激活即生效
##   MapEffect      地图，占位
## [endcodeblock]
##
## 基类只声明作用域，不声明执行方法 —— 各分支的调用签名本就不同
## （战斗要 RuleContext，掉落要 LootContext），强行统一只会得到一个没人能用的签名。
@abstract
class_name Effect
extends Resource

## 本效果属于哪个作用域，见 [EffectScope]
@abstract func scope() -> StringName

## 给 UI 与编辑器的一行说明
func describe() -> String:
	return ""
