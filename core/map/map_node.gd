## 地图上的一个点（架构文档 5.2）。**拓扑无关** —— 本类不知道地图长什么形状。
##
## 形状相关的一切都在 [member layout] 里：那是生成器写、布局策略读的自由字典，
## 本类与 [MapGraph]、[MapNavigator] 一个键都不解读。而且它**只记次序，不记坐标** ——
## 点画在哪儿是渲染的事（5.9）。
##
## 纯 [RefCounted]，不进场景树。
class_name MapNode
extends RefCounted

## 只表示内容是否已消耗，**与可否通行无关**：走过的点照样能再走，只是不再产生任何东西。
## 战斗输了也算消耗（7.1）—— 每个点只答一次。
enum State { UNVISITED, VISITED }

var id: int = 0

## 事件类型：battle / elite / event / random / search / shop / rest / extract / junction / core（5.4）
var type: StringName = &""

## 危险等级：0 常规 / 1 中危 / 2 高危。叠在 [member tier] 之上，两者独立（5.5）
var danger: int = 0

## 所属危险区域的编号，0 = 常规区
var zone: int = 0

## 难度与奖励的档位，越高越难越肥
var tier: int = 0

## 侵蚀分档，越小越早被侵蚀（5.7）。
##
## [b]与 tier 是两个字段，哪怕第一章里它们数值相等也不要合并。[/b]
## 侵蚀的方向不必永远等于难度的方向 —— 「核心苏醒、由内向外扩散」的章节里两者正好相反。
var erosion_band: int = 0

## 该节点内容生成用的独立种子。
## 不叫 seed：那会遮住 GDScript 的全局函数 seed()。
var content_seed: int = 0

## 节点里有什么，**生成地图时就定好**，不是踩上去才掷骰（5.10）：
## 玩家在地图上就能看敌人的属性与背包，据此规划路线。
## `random` 是唯一留空的类型 —— 那正是它叫「随机」的意思。
var content: Dictionary = {}

var state: int = State.UNVISITED

## 布局载荷。键由生成器与布局策略约定，数据层不解读。
var layout: Dictionary = {}


func is_visited() -> bool:
	return state == State.VISITED


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": String(type),
		"danger": danger,
		"zone": zone,
		"tier": tier,
		"erosion_band": erosion_band,
		"content_seed": content_seed,
		"content": content.duplicate(true),
		"state": state,
		"layout": layout.duplicate(true),
	}


static func from_dict(d: Dictionary) -> MapNode:
	var n := MapNode.new()
	n.id = int(d.get("id", 0))
	n.type = StringName(d.get("type", ""))
	n.danger = int(d.get("danger", 0))
	n.zone = int(d.get("zone", 0))
	n.tier = int(d.get("tier", 0))
	n.erosion_band = int(d.get("erosion_band", 0))
	n.content_seed = int(d.get("content_seed", 0))
	n.content = MapGraph.normalize(d.get("content", {}))
	n.state = int(d.get("state", State.UNVISITED))
	n.layout = MapGraph.normalize(d.get("layout", {}))
	return n
