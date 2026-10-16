## 一种伤害类型的性质（架构文档 4.6）。
##
## 伤害类型本身只是一个标签，**它的行为全写在这里**，不写在结算代码的 if 里。
## 新增一种伤害（腐蚀、真实、精神…）＝ 加一份本资源并登记，结算管线一行不改。
##
## [b]刻意不与加成绑定。[/b] 属性修饰（[StatModifier]，133 起只有乘算 / 加算）管的是「加成怎么叠」，
## 伤害类型管的是「这一下怎么结算」，两者正交 ——
## 绑在一起就写不出「强化影响全部伤害」这种最常见的加成。
##
## 175 补充五（作者定）：伤害类型也**不管盖印** ——【造成伤害】和【施加元素】是两件事，
## 元素只从施加状态来（[ApplyStatus]，[ReactionResolver]）
class_name DamageTypeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 096：别的语言的名字，`{"en": "Fire"}`；界面用 [method Names.of] 取
@export var display_names: Dictionary = {}
## 096：一句说明（悬浮窗词条）。空 = 不写
@export_multiline var description: String = ""
## 096：别的语言的说明
@export var descriptions: Dictionary = {}

## 能否被护甲吸收。中毒之类的绕过护甲直接见血。
##
## 106 第八节（作者定）：原来还有一列「吃不吃护甲」，已删 —— 格挡按**来源**生效
## （武器造成的直接伤害吃格挡，buff 造成的不吃，见 [member DamagePacket.direct]），不按伤害类型。
@export var armor_absorbable: bool = true

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


## 175 补充四：**真实伤害** —— 跳过管线的 1b 加成、2 护甲、3 受伤前改写、4 格挡与「受到伤害」轴（含按类型的易伤），原值直接落血；
## damage 事件照发。补充五（作者定）：**只有流血是真实伤害** —— 导入器不许别的类型打开它
@export var pure: bool = false
## 175 补充五：这种伤害归哪一大类（空 = 自己的 id）。流血是「真实 · 物理」：family = `physical`，
## 将来按大类读的加成 / 减免（「物理伤害 +X%」）把它算进物理。读的时候用 [method family_of]
@export var family: StringName = &""

## 归哪一大类（没写 = 自己）
func family_of() -> StringName:
	return family if family != &"" else id
