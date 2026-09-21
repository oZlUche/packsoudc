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

## 占格形状。为 null 时本定义不可用。
@export var shape: ItemShape

@export var icon: Texture2D

## 稀有度档位，0 起。影响掉落权重与 UI 配色。
@export var rarity: int = 0

## 本身的价值：撤离结算、买卖、侵蚀损坏时的损失都看它（架构文档 6.4）。
## 0 = 按稀有度与尺寸算（[method ItemValue.of]），填正数则覆盖 ——
## 留给「小而贵」「大而贱」的特例。战斗力与价值是两回事，一件东西可以只占其一。
@export var value: int = 0

## 准入标签。容器级与包体级的准入都拿它比对。
@export var tags: Array[StringName] = []

## 本物品是否是「包」。包只在棋盘模式的容器里作为包生效，
## 躺在尸体或暂存区里时就是件普通异形物品。
@export var is_bag: bool = false

## 仅 is_bag 为真时有效：包内准入标签，为空表示不限。
## 「只收药水的药水带」这类语义用它表达 —— 本作没有装备栏。
@export var bag_accept_tags: Array[StringName] = []

## 仅 is_bag 为真时有效：施加给包内每件物品的效果。
## 「包内物品触发快 10%」这类语义放这里。
@export var bag_mods: Array[StatModifier] = []

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

@export_group("战斗")
## 战斗定义。为空表示本物品不参战（纯素材、纯包体）。
@export var combat: CombatProfile

## 邻接标记（增益／受益）。为空表示本物品与邻居无互动。
@export var adjacency: AdjacencyProfile


## 定义是否完整可用。资产批量校验与单元测试用。
func is_valid() -> bool:
	return id != &"" and shape != null and shape.is_valid()


## 该定义在指定旋转下的占格。
func cells_rotated(rot: int) -> Array[Vector2i]:
	if shape == null:
		return [] as Array[Vector2i]
	return shape.cells_rotated(rot)
