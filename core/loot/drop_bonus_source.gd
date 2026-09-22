## 掉落率修正的来源（架构文档 6.1）：难度与幸运值是 [LootContext] 自带的两个数，
## **局外 buff 与地图 buff 走这里** —— 作者要求留空占位、保留接口方法。
##
## 一个来源回答两件事：这件（敌人自己的）道具的掉落率加多少、珍宝概率加多少。
## 都是加法，单位与 [DropRule] 的概率一样（0.05 = 5 个百分点）。
## 谁把来源塞进 LootContext 是持有方的事（将来是 RunState：开局把局外 buff 装进去，进图把地图 buff 装进去）。
@abstract
class_name DropBonusSource
extends RefCounted


## 这件道具的掉落率加多少
@abstract func owned_bonus(ctx: LootContext, def: ItemDef) -> float

## 珍宝概率加多少
@abstract func treasure_bonus(ctx: LootContext) -> float


## 给人看的一句话（沙盒、日志）
func describe() -> String:
	return ""
