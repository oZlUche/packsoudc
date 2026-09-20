## 战斗属性的键名。
##
## 属性用 [StringName] 作键而不是枚举：属性之间彼此独立，没有像乘区那样的
## 「顺序影响取整」问题，因此内容可以自由新增键名而不牵动任何已有数值。
## 需要严格顺序约定的只有 [enum StatMath.Buff]。
class_name BattleStats
extends RefCounted

## 单次触发造成的伤害
const DAMAGE := &"damage"

## 基础冷却，单位：秒（定点）
const COOLDOWN := &"cooldown"

## 触发速度倍率，基础 1.0。越大越快。
## 冷却不直接吃加成 —— 「更快」在语义上是速度变大，而不是冷却时间变大，
## 若把加成加在 COOLDOWN 上，+20% 会让物品变慢，与直觉相反。
const HASTE := &"haste"

## 最大生命值
const MAX_HP := &"max_hp"

## 护甲，减伤用
const ARMOR := &"armor"
