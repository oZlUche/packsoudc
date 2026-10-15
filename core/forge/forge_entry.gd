## 铸炉映射表的一行（175 第三批 §3.2）：一件道具放进某个槽，按它的【材质】/【用途】/【稀有度】查到这一行，读出一个字段。
##
## 三个槽（[ForgeTable.slot]）各读不同的字段，所以一行只填和自己那张表相关的几项，其余留空：
## [codeblock]
## 时机槽  材质 → trigger（什么时候）   用途 → trigger_props（方向）   稀有度 → cadence（多久一次）
## 效果槽  材质 → effect / upgraded / bonus、amount_field、base、prefix   用途 → target（给谁）   稀有度 → tier（几阶）
## 数值槽  材质 → mult   用途 → mult   稀有度 → size（几档）
## [endcodeblock]
## **全是数据**（和 146 构件库一样，扳机 / 节奏 / 效果可以写 `"@构件 id"`），拼规则在 [Forge] 里，不按材质写代码分支
class_name ForgeEntry
extends Resource

## 这一行认哪个标签（材质 / 用途表）或几档稀有度（"0".."4"）；`default` = 查不到时落到这一行
@export var key: StringName = &""

@export_group("时机槽")
## 什么时候（材质）
@export var trigger: Trigger
## 把这几项写到扳机上（用途）：`{"direction": "DEALT"}` —— 扳机没有这一项就不写
@export var trigger_props: Dictionary = {}
## 多久一次（稀有度）
@export var cadence: Cadence
## 材质行：这种时机不看稀有度、固定用这个节奏（开战时只有一次，写 always）；空 = 按稀有度
@export var fixed_cadence: Cadence

@export_group("效果槽")
## 做什么（材质），0–1 阶用它
@export var effect: CombatEffect
## 2 阶起换成它（流血 → 大量流血）；空 = 一直用 effect
@export var upgraded: CombatEffect
## 4 阶再附带的那一个；空 = 没有
@export var bonus: CombatEffect
## 数值写到效果的哪一项（`stacks` / `amount`）
@export var amount_field: StringName = &"amount"
## 一档数值时那一项是多少
@export var base: float = 1.0
## 只能给自己（加护甲、回血）：用途的「给谁」不改它
@export var self_only: bool = false
## 附魔前缀（「嗜血的」）；各语言另写 [member prefixes]
@export var prefix: String = ""
@export var prefixes: Dictionary = {}
## 晶石这类：按这件道具自己的元素换 —— 元素 → `{"damage_type": "fire", "prefix": "燃烧的", "prefixes": {...}, "applies": {"buff": "scorch"}}`，
## 除前缀、applies 外的键写到效果的同名项上（`buff` 按 id 查 buff）；空 = 不按元素换。
## 175 补充五：`applies` 是另加的一个施加效果（伤害不再顺手盖印），层数按阶（[method Forge._element_apply]）
@export var by_element: Dictionary = {}
## 给谁（用途）：0 = 对手、1 = 自己（[enum CombatEffect.Target]）；-1 = 不改
@export var target: int = -1
## 几阶（稀有度）：0 = 基础、1 = 升阶、2 = 升阶并附带
@export var tier: int = 0

@export_group("数值槽")
## 数值乘几（材质 / 用途）
@export var mult: float = 1.0
## 几档（稀有度）：一档数值 × 它
@export var size: float = 1.0
