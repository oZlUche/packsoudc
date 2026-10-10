## 物品的邻接标记（架构文档 4.2）。
##
## 标记格是物品[b]轮廓之外[/b]的相邻格，偏移相对物品原点书写，随物品一起旋转
## （走 [method ItemShape.transform_point]，与形状共用同一套平移量）。
##
## 两类标记按[b]语义[/b]划分，而不是按符号：
##
## [codeblock]
## 增益 grant   —— 我给站在这些格子上的邻居加成
## 受益 receive —— 站在这些格子上的邻居给我加成
## 供给 feed    —— 我站在谁的受益格上，就给谁（148；不画格子）
## [endcodeblock]
##
## 参照作品用星形与菱形区分两类标记，那只是两个任意符号；本作直接用语义命名，
## 省掉「标记类型」与「效果方向」两个概念的拆分。UI 上用什么图形表示是表现层的事。
##
## [b]注意：这不是宝石镶嵌。[/b] 邻接标记是「谁挨着谁」，双方各占各的格子；
## 宝石是放进宿主物品孔位、不占网格的另一套系统，尚未实现，
## socket / 镶嵌 这组词留给它。
##
## 点亮规则是[b]去重计数[/b]：一件物品最多只能填另一件的一个增益格、一个受益格，
## 所以「点亮数 = 占住标记格的不同物品数量」。这与遍历顺序无关，不需要匹配算法。
##
## [b]硬约束：同一类标记的各个格子必须同质。[/b] 若某天要让一号格管伤害、二号格管冷却，
## 就得先决定「谁分配到哪个格」，问题会退化成二分匹配 —— 越这条线之前先改架构文档 4.2。
class_name AdjacencyProfile
extends Resource

@export_group("增益：我给邻居加成")
## 增益标记格的偏移，相对物品原点
@export var grant_cells: Array[Vector2i] = []
## 受益方条件：为空表示任何物品都算，否则邻居的标签需命中其一
@export var grant_filter: Array[StringName] = []
## 每个符合条件的邻居各得一份
@export var grant_mods: Array[StatModifier] = []
## 108（作者定）：给站在增益格上的邻居**挂规则**（毒箭挨着弓：弓每次出手附带一层中毒）。每个点亮的邻居各挂一份，
## 规则以**邻居**的身份跑（`item_stat` 读邻居的、伤害包来源是邻居），触发器只许 `on_item_fired`、编译时绑成只听那个邻居。
## 和 [member grant_mods] 互不排斥：两样都写就是「+20% 且附毒」
@export var grant_rules: Array[AbilityRule] = []

@export_group("受益：邻居给我加成")
@export var receive_cells: Array[Vector2i] = []
@export var receive_filter: Array[StringName] = []
## 点亮几个格，本物品就得几份
@export var receive_mods: Array[StatModifier] = []
## 132：受益规则 —— 每点亮一个受益格，**本件**多挂一份（以本件为来源，悬浮窗写「附加：… ← 邻居」）。
## 跑在本件身上，所以时机不限；不许有 costs（同附加规则）
@export var receive_rules: Array[AbilityRule] = []

@export_group("供给：我站在别人的受益格上时给他")
## 148（作者定，魔晶石 → 法杖）：**本件站在别人的受益格上**、且对方命中 [member feed_filter] 时，把这些交给对方 —— 一份，不按格数乘。
## 供给方不画格子：「谁的受益格我站上了」由宿主说了算（晶石形状转四个方向，画一圈增益格才对得上杖头）。用坏了（耐久归零）就不再供给
@export var feed_mods: Array[StatModifier] = []
## 供给的规则：挂到宿主身上、以宿主身份跑（同 108 的附加规则：只许 `on_item_fired`、不许 costs）
@export var feed_rules: Array[AbilityRule] = []
## 宿主要命中的标签；空 = 任何宿主
@export var feed_filter: Array[StringName] = []


func has_grant() -> bool:
	return not grant_cells.is_empty() and (not grant_mods.is_empty() or not grant_rules.is_empty())


func has_receive() -> bool:
	return not receive_cells.is_empty() and (not receive_mods.is_empty() or not receive_rules.is_empty())


## 148：有没有供给（站在别人受益格上时给的东西）
func has_feed() -> bool:
	return not feed_mods.is_empty() or not feed_rules.is_empty()


## 某个定义是否满足标记的过滤条件。
static func accepts(filter: Array[StringName], def: ItemDef) -> bool:
	if filter.is_empty():
		return true
	if def == null:
		return false
	for tag in def.tags:
		if filter.has(tag):
			return true
	return false
