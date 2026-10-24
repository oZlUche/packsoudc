## 物品的静态定义：全局共享、只读。
##
## 与 [ItemInstance] 严格分开 —— 定义描述「这是什么」，实例描述「这一件现在怎么样」。
## 存档只写 [member id] 字符串，绝不写资源路径，否则挪动 .tres 会让旧存档失效。
##
## 战斗相关字段（冷却、伤害、邻接加成）属于 M2，届时直接在本类追加导出属性即可，
## Godot 对 .tres 中缺失的新属性会取默认值，不会破坏已有资产。
class_name ItemDef
extends Resource

## 全局唯一标识，同时是存档键。一经发布不得修改。
@export var id: StringName = &""

@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
## 088：给玩家看的一句说明（悬浮窗、图鉴）。空 = 不写
@export_multiline var description: String = ""
## 221 F1：别的语言的说明，`{"en": "…"}`；界面用 [method Names.description_of] 取
@export var descriptions: Dictionary = {}

## 占格形状。为 null 时本定义不可用。
@export var shape: ItemShape

## 稀有度档位，0 起。影响掉落权重与 UI 配色。
@export var rarity: int = 0

## 本身的价值：撤离结算、买卖、侵蚀损坏时的损失都看它（架构文档 6.4）。
## 0 = 按稀有度与尺寸算（[method ItemValue.of]），填正数则覆盖 ——
## 留给「小而贵」「大而贱」的特例。战斗力与价值是两回事，一件东西可以只占其一。
@export var value: int = 0

## 129：重量（单位「重」）。0 = 按格数与材质类算（[method ItemWeight.of]），填正数则覆盖 ——
## 留给「看着小其实沉」「占地方其实轻」的特例。负重只算作战棋盘上的（含包本身）
@export var weight: int = 0

## 封存（第 8 阶段 8-4 起）：带这个标签的道具**数据保留、不再出现**。正式游戏的世界观是剑与魔法（docs/worldview.md），
## 现代道具（枪械、弹匣、电池、无人机……）全部封存 —— 不进搜索、掉落、商店、敌人的装备、图鉴与编辑器的下拉，
## 但按 id 仍取得到（旧存档、仓库里的还认）。[ItemDatabase.ids] 是唯一拦它的地方
const SEALED := &"sealed"
## 088（作者定）：**特殊道具** —— 不进背包、不能生成（搜索 / 掉落 / 商店 / 敌人都不出），拿到只是文本通知 + 图鉴点亮；
## 它代表一种能力（望远镜 → 节点浮窗），能力由它别的标签说明（`node_tooltips`）
const KEEPSAKE := &"keepsake"
## 信仰（8-4，报告 081）：信仰道具带 `faith`，再带一个信仰对象标签 `faith:<id>`（[FaithTags.PREFIX]）。激活规则见 [FaithState]
const FAITH := &"faith"
## 095：赐福版（从普通道具派生的信仰道具）；信物（护符 / 符号 / 遗物）—— 只有信物能激活信仰
const BLESSED := &"blessed"
const ANCHOR := &"faith_anchor"
## 175 第三批：铸牌这类**内部道具** —— 不进图鉴、掉落、商店（[method ItemDatabase.ids] 拦），能带出、能存仓库
const TOKEN := &"token"
## 244：金银（金块 / 金条）—— 只有商店出（[ShopSession] 单开一格）、不参战不进配方、不算总分，基地按面值全额回收。
## 搜索、掉落、敌人装备、头一回踩点白给这些「从全库里抽」的地方都跳过它（[method is_bullion]）
const BULLION := &"bullion"
## 244 补充一：贵重品（金银、魔晶石……）—— 值钱是它的本分，基地回收按面值全额（[method is_valuable]）
const VALUABLE := &"valuable"

## 准入标签。容器级与包体级的准入都拿它比对。
@export var tags: Array[StringName] = []


func is_sealed() -> bool:
	return tags.has(SEALED)


func is_keepsake() -> bool:
	return tags.has(KEEPSAKE)


## 244：金银（[constant BULLION]）
func is_bullion() -> bool:
	return tags.has(BULLION)


## 244 补充一：贵重品（[constant VALUABLE]）
func is_valuable() -> bool:
	return tags.has(VALUABLE)


## 175：铸牌（[constant TOKEN]）
func is_token() -> bool:
	return tags.has(TOKEN)


func has_faith() -> bool:
	return tags.has(FAITH)


## 095：是派生出来的赐福版（手写的「赐福的长弓」不算：它有自己的文件与功能）
func is_blessed() -> bool:
	return blessed_of != &""


## 能激活信仰的信物（095）：带 faith_anchor
func is_anchor() -> bool:
	return has_faith() and tags.has(ANCHOR)


## 144：这件东西在局里「起作用」—— 有战斗属性或规则、增益格、跨域效果、包体加成、信力加成，是包，或是信物 / 特殊道具。
## 其余（材料、珍宝、战利品……）只有价值和重量。从定义算，不是标签：作者给材料加了 combat，它自己就算有效果
func has_effect() -> bool:
	if combat != null and (not combat.base_stats.is_empty() or not combat.rules.is_empty()):
		return true
	if adjacency != null or is_bag:
		return true
	if not effects.is_empty() or not bag_mods.is_empty() or not faith_bonuses.is_empty() or growth != null:
		return true
	return tags.has(ANCHOR) or is_keepsake()


## 信仰对象标签（`faith:violence`）；没有返回空。带 `faith` 却没有对象标签也返回空 —— 导入器不许这种道具进来
func faith_tag() -> StringName:
	for t in tags:
		if String(t).begins_with(FaithTags.PREFIX):
			return t
	return &""


## 本物品是否是「包」。包只在棋盘模式的容器里作为包生效，
## 躺在尸体或地上时就是件普通异形物品。
@export var is_bag: bool = false

## 仅 is_bag 为真时有效：包内准入标签，为空表示不限。
## 「只收药水的药水带」这类语义用它表达 —— 本作没有装备栏。
@export var bag_accept_tags: Array[StringName] = []

## 仅 is_bag 为真时有效：施加给包内每件物品的效果。
## 「包内物品触发快 10%」这类语义放这里。
@export var bag_mods: Array[StatModifier] = []
## 209：仅 is_bag 为真时有效：里面的魔晶石供给一场不扣耐久（[WearModule]）
@export var bag_wear_free: bool = false
## 209：仅 is_bag 为真时有效：里面的东西卖价倍率（撤离结算、悬浮窗的「值」，[method ItemValue.of_in]）
@export var bag_value_mult: float = 1.0
## 209：仅 is_bag 为真时有效：里面的东西负重倍率（[method ItemWeight.total]、[method ItemWeight.of_in]）
@export var bag_weight_mult: float = 1.0

## 所属套装的 id，为空表示不属于任何套装。
##
## **只是归属标记**，套装效果本身写在 ItemSetDef 上。物品界面显示的套装信息
## 纯粹是 UI 提示（按激活状态暗／亮切换），不参与任何结算。
@export var set_id: StringName = &""

## 非战斗作用域的效果（战利品、地图…）。**激活即生效，不需要扳机。**
##
## 「这把刀让敌人多掉一件东西」这类道具靠它表达 ——
## 掉落效果不再是套装专有。战斗效果请写在 combat.rules 里，它们需要扳机。
@export var effects: Array[Effect] = []

## 信力（报告 082）：信仰道具在信力过了第 n 阶之后多出来的功能（属性修饰、规则），只对带信仰标签的道具有意义。
## 编译器按「信仰 → 现在第几阶」并入（[BattleCompiler.compile] 的 faith_tiers）
@export var faith_bonuses: Array[FaithBonus] = []
## 095：赐福版从哪件派生（空 = 不是派生的）
@export var blessed_of: StringName = &""
## 087（作者定）：信仰道具**休眠**（别的信仰激活着）时还保不保留自己的战斗定义（`combat`：盾的固定减伤、武器本身的攻击力……
## 这些是「通用效果」）。保留的只丢信力加成、邻接与套装；不保留 = 彻底失效（护符这类只靠信仰起作用的东西写 false）。
## 没有 combat 的道具这个开关无意义（本来就没有通用效果）
@export var dormant_keeps_combat: bool = true
## 091（作者定）：局外解锁 id（成就给的）；没解锁就不出现在搜索 / 掉落 / 商店 / 敌人的池里（[method ItemDatabase.ids] 拦），
## 图鉴里灰着写「未解锁」。空 = 一直可得。指名给的（事件 give_item、敌人招牌）不受它管
@export var requires_unlock: StringName = &""

@export_group("战斗")
## 战斗定义。为空表示本物品不参战（纯素材、纯包体）。
@export var combat: CombatProfile

## 邻接标记（增益／受益）。为空表示本物品与邻居无互动。
@export var adjacency: AdjacencyProfile

## 175 补充五：「造成伤害后施加」的简写 —— `[{"buff": "scorch", "stacks": 1}]`：这件道具每打中一下，给对手叠这几层。
## 编译时拼成一条 on_damage 规则挂上（[method ElementApply.rule_of]，来源 `applies`）。【造成伤害】和【施加元素】是两件事，
## 道具带哪种元素只看它施加什么（[method ReactionResolver.elements_of_item]）
@export var applies: Array[ElementApply] = []

@export_group("魔兽持有")
## 212：**一件道具两套逻辑** —— 魔兽（[member EnemyDef.species] 不是 human）自己持有这件时用它代替 [member combat]；
## 那时 [member adjacency]、[member applies]、[member faith_bonuses] 都不生效（魔兽没有邻接、没有信仰）。
## null = 魔兽持有时和玩家一样。掉下来就是玩家版（同一件，不换 id）
@export var wild: CombatProfile
## 212：魔兽持有时的「打中后施加」（写法同 [member applies]）
@export var wild_applies: Array[ElementApply] = []

@export_group("附魔")
## 175 第三批（作者定：所有附魔都视为铸牌附魔）：预置附魔 —— 实例的 `state.enchant`（铸牌附上的）覆盖它，见 [Forge]
@export var enchant: EnchantDef

@export_group("耐久")
## 148：耐久（次数制，魔晶石）。为空 = 不会用坏。剩几次记在实例上（[method ItemInstance.charges]）
@export var wear: WearProfile
## 246 补充二：魔晶石的元素家族（`fire` / `frost` / `lightning`）—— 掉落里滚到它就在同家族的三品里等概率换一件（[CrystalRoll]）。
## 空 = 不换品（清明、琥珀这样的通用供给）
@export var crystal_family: StringName = &""

@export_group("生长")
## 207：自然系专属的生长（种子 → 茎叶 → 绽放）。为空 = 不会长。走到哪一阶记在实例上（[GrowthProfile]）
@export var growth: GrowthProfile


## 定义是否完整可用。资产批量校验与单元测试用。
func is_valid() -> bool:
	return id != &"" and shape != null and shape.is_valid()


## 该定义在指定旋转下的占格。
func cells_rotated(rot: int) -> Array[Vector2i]:
	if shape == null:
		return [] as Array[Vector2i]
	return shape.cells_rotated(rot)


## 占格数；形状为空算 0（那是非法定义，导入器拦着，库里没有）
func cell_count() -> int:
	return shape.cell_count() if shape != null else 0
