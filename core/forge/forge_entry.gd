## 铸炉映射表的一行（175 第三批 §3.2）：一件道具放进某个槽，按它的【材质】/【用途】/【稀有度】查到这一行，读出一个字段。
##
## 三个槽（[ForgeTable.slot]）各读不同的字段，所以一行只填和自己那张表相关的几项，其余留空：
## [codeblock]
## 时机槽  材质 → trigger（什么时候）   用途 → trigger_props（方向）、cadence_mult（节奏系数）   稀有度 → cadence（多久一次）
## 效果槽  材质 → 攻式 effect / upgraded / bonus 与守式 guard_*、amount_field、base、prefix   用途 → stance（攻 / 守）   稀有度 → tier（几阶）、main_mult
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
## 195（用途）：冷却秒数乘几（武器 0.75 快、盾 1、防具 1.25 慢）；每次触发、固定节奏不乘
@export var cadence_mult: float = 1.0
## 多久一次（稀有度）
@export var cadence: Cadence
## 材质行：这种时机不看稀有度、固定用这个节奏（开战时只有一次，写 always）；空 = 按稀有度
@export var fixed_cadence: Cadence

@export_group("效果槽")
## 攻式（材质）：基础句（数值写进它）。195：用途是武器与其它时用攻式
@export var effect: CombatEffect
## 攻式升阶：1 阶起**追加**在基础句后面（195 起不再替换）；空 = 没有
@export var upgraded: CombatEffect
## 攻式附带：2 阶起再追加；空 = 没有
@export var bonus: CombatEffect
## 攻式基础句的数值写到效果的哪一项（`stacks` / `amount` / `delta`；负的照负号写）；空 = 不写数
@export var amount_field: StringName = &"amount"
## 攻式一档数值时那一项是多少
@export var base: float = 1.0
## 195 守式（材质）：用途是盾、防具时用这一套 —— 基础句、升阶、附带，各自写好给谁
@export var guard_effect: CombatEffect
@export var guard_upgraded: CombatEffect
@export var guard_bonus: CombatEffect
## 守式基础句的数值写到哪一项；空 = 不写数（弹开这类不可叠的）
@export var guard_amount_field: StringName = &"amount"
## 守式一档数值
@export var guard_base: float = 1.0
## 守式前缀（「铁壁的」）；各语言另写 [member guard_prefixes]
@export var guard_prefix: String = ""
@export var guard_prefixes: Dictionary = {}
## 只能给自己（加护甲、回血）：用途的「给谁」不改它
@export var self_only: bool = false
## 附魔前缀（「嗜血的」）；各语言另写 [member prefixes]
@export var prefix: String = ""
@export var prefixes: Dictionary = {}
## 晶石这类：按这件道具自己的元素换 —— 元素 → `{"damage_type": "fire", "prefix": "燃烧的", "prefixes": {...}, "applies": {"buff": "scorch"}}`，
## 除前缀、applies 外的键写到效果的同名项上（`buff` 按 id 查 buff）；空 = 不按元素换。
## 175 补充五：`applies` 是另加的一个施加效果（伤害不再顺手盖印），层数按阶（[method Forge._element_apply]）
@export var by_element: Dictionary = {}
## 给谁（用途）：0 = 对手、1 = 自己（[enum CombatEffect.Target]）；-1 = 不改。195 起表里不再写（效果自带给谁），留着读老表
@export var target: int = -1
## 195 攻守（用途）：`attack` / `guard`，空 = attack
@export var stance: StringName = &""
## 几阶（稀有度）：0 = 基础、1 = 加升阶、2 = 再加附带
@export var tier: int = 0
## 195（稀有度）：基础句的数再乘几（4 档 1.5、5 档 2）
@export var main_mult: float = 1.0

@export_group("数值槽")
## 数值乘几（材质 / 用途）
@export var mult: float = 1.0
## 几档（稀有度）：一档数值 × 它
@export var size: float = 1.0
