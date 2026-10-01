## 一种伤害类型的性质（架构文档 4.6）。
##
## 伤害类型本身只是一个标签，**它的行为全写在这里**，不写在结算代码的 if 里。
## 新增一种伤害（腐蚀、真实、精神…）＝ 加一份本资源并登记，结算管线一行不改。
##
## [b]刻意不与乘区绑定。[/b] 乘区（[enum StatMath.Buff]）管的是「加成怎么叠」，
## 伤害类型管的是「这一下怎么结算」，两者正交 ——
## 绑在一起就写不出「强化影响全部伤害」这种最常见的加成。
class_name DamageTypeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 能否被护盾吸收。中毒之类的绕过护盾直接见血。
@export var shield_absorbable: bool = true

## 是否吃护甲减免
@export var armor_applies: bool = true

## 这一下会不会**招致反应** —— 反伤、吸血、格挡这类由挨打／打人触发的规则。
##
## [b]只有直接攻击为 true。[/b] 间接伤害一律 false：
##
## [codeblock]
## poison / bleed   持续伤害。每秒跳一次，若能招致反伤，一个中毒 buff 就能
##                  把反伤刷成主要输出，而玩家根本没在攻击
## reflect          反伤本身。A 反 B、B 再反 A —— 两件反伤道具会互相引燃
## drain            流失。超频自伤、以血为代价；能招致吸血的话，
##                  割自己一刀就成了正收益
## [endcodeblock]
##
## [b]这不是靠递归上限挡住的。[/b] 上限（BattleContext.MAX_DAMAGE_DEPTH）是兜底，
## 用来在内容配错时给出可定位的告警；「反伤不该引发反伤」是语义，必须写在这里。
## 靠上限截断意味着对轰仍然发生了四轮，只是没打穿栈而已。
##
## 也不是一刀切的屏蔽：**显式指定了类型的扳机照样听得见**。
## 「中毒时净化」「流失时回一口气」这类联动靠的就是这个口子 ——
## 作者写下类型名，就表示他知道自己在监听什么。
@export var provokes: bool = true


func describe() -> String:
	var parts: Array[String] = []
	if not shield_absorbable:
		parts.append("无视护盾")
	if not armor_applies:
		parts.append("无视防护")
	if not provokes:
		parts.append("不招致反应")
	return "、".join(parts) if not parts.is_empty() else "常规"
