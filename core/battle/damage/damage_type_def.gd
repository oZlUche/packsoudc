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

## 是否触发「受到／造成伤害时」的默认监听。
##
## [b]流失（drain）为 false[/b]：超频自伤、以血为代价这类血量变化同样走伤害管线
## （好让减伤、护盾、反转这些机制统一生效），但它不该点亮反伤与吸血 ——
## 那会让「割自己一刀」变成一种正收益。
##
## 这不是一刀切的屏蔽：**显式指定了类型的扳机照样听得见**，
## 「流失时回一口气」这类联动效果靠的就是这个口子。
@export var notifies: bool = true


func describe() -> String:
	var parts: Array[String] = []
	if not shield_absorbable:
		parts.append("无视护盾")
	if not armor_applies:
		parts.append("无视护甲")
	if not notifies:
		parts.append("不触发受伤效果")
	return "、".join(parts) if not parts.is_empty() else "常规"
