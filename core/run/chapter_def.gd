## 一章：地图从哪来，加上将来的侵蚀日程、敌人池与掉落表（架构文档 5.3 / 7）。
##
## 它是作者数据，走内容管线（10 节）：`data/authoring/chapters/*.json` 导入成
## `data/chapters/*.tres`。导入器不认识它 —— 反射填字段，和道具一样。
##
## 侵蚀日程（第 7 阶段）、掉落表（M4-2）到时候各加一个字段，导入器、导出器、编辑器一行不改 ——
## 敌人池（M4-1）就是这么加进来的。
class_name ChapterDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}

## 随机生成还是载入预设，见 5.3.1
@export var map_source: MapSource = null

## 敌人池的 id（`data/enemy_pools/`，6.0）。空 = 这一章没有敌人（战斗点空着）。
## 按 id 引用而不是内联：几章共用一个池、只改难度是常态
@export var enemy_pool: StringName = &""

## 章节难度，0 起。敌人池的 [StrengthRule] 按它抬档位，掉落规则按它加掉落率；侵蚀将来也看它
@export var difficulty: int = 0

## 掉落规则的 id（`data/drop_rules/`，6.1）。空 = 这一章什么都不掉
@export var drop_rule: StringName = &""

## 126：敌人携带规则的 id（`data/carry_rules/`）：敌人身上随机带几件非战斗道具。空 = 不带（序章不带：教程敌人身上的东西是设计好的）
@export var carry_rule: StringName = &""

## 129：负重规则的 id（`data/encumbrance_rules/`）：超重分几级、每级减什么、走路翻不翻倍。空 = 这一章不算负重（序章不算）
@export var encumbrance_rules: StringName = &""

## 节点规则的 id（`data/node_rules/`，6.2 / 7.1）：随机点变什么、搜索怎么搜、输了扣多少、休息回多少。
## 空 = 踩到点只标用过，什么都不发生
@export var node_rules: StringName = &""

## 经济规则的 id（`data/economy_rules/`，6.6）：打赢给多少钱、商店、付费撤离点。空 = 这一章不算钱
@export var economy_rules: StringName = &""

@export_group("开局屏（083）")
## 开局屏上的先后（小的在前）；序章 0 ~ 2、自由模式 3
@export var order: int = 0
## 局外解锁 id（[MetaState.unlocks]）：没解锁不列。空 = 一直可选
@export var requires_unlock: StringName = &""
## 撤离成功给的局外解锁 id（序章通关解锁下一张、序章三解锁自由模式）。空 = 不给
@export var grants_unlock: StringName = &""
## 能选的角色 id；空 = 全部
@export var characters: Array[StringName] = []
## 拿到这个局外解锁之后就不再列（084：教程通关就收起，下一张教程图顶上来直接开）。空 = 一直列
@export var hidden_by_unlock: StringName = &""
## 这一章开局多给的体力（084：第二张教程图两场都输也死不了）
@export var vitality_bonus: int = 0
## 这一章开局发的道具 id（在角色的初始包之上；序章二发一把匕首）。放不进包的到地上
@export var starting_items: Array[StringName] = []
## 160 补一：这一章开局发的随身技能 id（写几次发几个；进腰带，不是道具）
@export var starting_belt: Array[StringName] = []
## 088（作者定）：这一章开局发的**特殊道具**（不进背包，只是文本通知 + 图鉴点亮；序章二发望远镜 → 节点浮窗）。记在局外，以后每一局都有
@export var starting_keepsakes: Array[StringName] = []
## 撤离成功之后直接进的下一章（085 作者定：序章撤离后不是再来一局而是下一张教学图）。空 = 照常去局外
@export var next_chapter: StringName = &""
## 开局能不能从仓库带东西进来（序章不能：教程从空包开始）
@export var allow_carry_in: bool = true
## 开局直接站在第一个出生点上，不用挑（084：序章只有一条路、一个出生点）
@export var auto_spawn: bool = false
## 不走开局屏（084，作者：序章不要开局页面）：主菜单「新的一局」时只有这一章可选就直接开，角色取这一章列的第一个、种子随机
@export var skip_setup: bool = false
## 开局先过的事件（intro）：站到出生点之后、地图能动之前弹一屏事件（`data/events/` 里的 id）。空 = 不弹
@export var intro_event: StringName = &""
## 091（作者定 10.2 第 3 条）：这一章的「本图规则」卡（≤ 3 条）—— 第一次进图弹一页（局外记住看过了），暂停菜单里能再看。空 = 不弹
@export var rules: Array[String] = []
## 166（作者定）：这一章开头的界面教程（`data/authoring/coach/<id>.json` 的步骤：阴影里挖洞指着顶端栏的读数，点哪都下一步）。
## 第一次露出地图时放一次（[member MetaState.coach_seen]），调试台能重放。空 = 不放；序章一是 `prologue_map`
@export var coach: StringName = &""
## 166 补充二：这一章第一场战斗的界面教程（同一种步骤文件，目标是回放层的控件 —— [constant BattleView.COACH_TARGETS]）。
## 战斗屏淡入后放一次，期间回放停着；看过记在 [member MetaState.coach_seen]。空 = 不放；序章一是 `prologue_battle`
@export var coach_battle: StringName = &""

@export_group("一局的模块（101）")
## 101 第 0 刀：这一局装哪些**本体模块**（[RunModule] 构件，各带参数）。空 = 用默认清单（[method RunModules.standard]）。
## 难度开的机制是另一层（[member DifficultyDef.mechanics]），两层叠加。加一种玩法 = 一个子类 + 注册表一行 + 这里一条
@export var modules: Array[RunModule] = []

@export_group("全局倒计时与保险箱（092，作者定）")
## 全局倒计时：这一局一共能花多少行动点（每走一步 -1，边的 action_cost 大于 1 就多扣）；归零 = 行动失败（战败结算，只有保险箱里的带得出）。0 = 这一章没有倒计时。
## 倒计时和地图规模正相关：环形配置的每个规模（`scales[].step_limit`）写了就用它的，这里是兜底
@export var step_limit: int = 0
## 倒计时过半时关掉一个撤离点（离出生点最近的免费撤离点；地图上标着「倒计时剩 n 时关闭」）。要有 step_limit 才生效
@export var closing_extract: bool = true
## 这一章放几个保险箱点（生成之后挑靠近中央的战斗 / 事件点覆盖成保险箱，和高危区一样是生成后的一遍；预设图直接画 K）。放进去的视为已带出，战败也带得出；**关上就送回基地，不能再改**
@export var safes: int = 0
## 154：宝箱屏的皮肤 id（`data/chest_skins/`）：背景、宝箱的纹路与材质跟着地图走
@export var chest_skin: StringName = &"ruins"
## 作者定：地图屏的手绘底图 id（`assets/maps/<id>.png`，[MapSkin]）—— 每章一种风格；没这张图照旧石板底
@export var map_skin: StringName = &"ruins"

@export_group("带入预算（094，作者定）")
## 从仓库带进这一局的道具**总价值**（ItemValue）预算；0 = 不限。预设 / 角色的初始包不算。规模档写了 carry_budget 就用规模档的
@export var carry_budget: int = 0
## 超预算换代价：每超这么多价值，全局倒计时 −1（0 = 超了也不罚，只提示）
@export var carry_over_cost: int = 50

@export_group("节点浮窗（084，第二章开放）")
## 鼠标移到节点上显示浮窗（敌人数据与背包 / 用过了 / 可能发生什么 / 值得搜）。默认关 —— 正式的开法是拿到带 `node_tooltips` 标签的
## 特殊道具（望远镜，088）；这个开关留给不想走道具那条路的章节
@export var node_tooltips: bool = false
## "default" 用内置模板；"custom" 用 [member tooltip_texts] 里按类别写的模板（缺的类别退回内置）
@export var tooltip_mode: String = "default"
## 类别 → 模板（占位符见 docs/text-placeholders.md：{battle_data}、{enemy_name}、{node_type}……）。类别：battle / visited / search / event / shop / rest / extract / random / other
@export var tooltip_texts: Dictionary = {}


## 这个角色在这一章能不能选
func allows_character(id: StringName) -> bool:
	return characters.is_empty() or characters.has(id)
