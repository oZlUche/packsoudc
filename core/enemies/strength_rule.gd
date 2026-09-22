## 一个节点想要几档的敌人（架构文档 6.0）。
##
## 输入是节点自己身上的东西：深度（tier 归一化到 0～1，形态无关）、危险等级（5.5：
## 叠在 tier 之上）、节点类型（精英、核心），再加章节难度与地图规模两个外部偏移。
## 全是加法：每一项各管一件事，调哪个都看得出来。
class_name StrengthRule
extends Resource

## 最外 → 最内的档位（按深度线性插值再四舍五入）
@export var by_depth: Vector2i = Vector2i(0, 2)

## 危险等级每一级加几档
@export var danger_bonus: int = 1

## 节点类型 → 加几档。例：{"elite": 1, "core": 2}
@export var type_bonus: Dictionary = {}

## 章节难度每 +1 加几档
@export var difficulty_bonus: int = 1

## 地图规模 id → 加几档。例：{"large": 1}。没列的规模不加
@export var by_scale: Dictionary = {}

## 挑人时本色档位允许离想要的档位多远；范围内一个都没有就取最近的
@export var tolerance: int = 1

@export_group("探索度")
## 只对**踩上去才造**的敌人生效（随机点揭成的战斗、搜索点的遭遇）：地图上看得见的敌人生成时就定了，不随探索变。
## 作者的要求：这类敌人的强度要跟探索度挂钩 —— 当前位置（上面的深度与危险）、总步数、搜索次数。
## 总步数每走这么多步加一档，0 = 不算
@export var steps_per_tier: int = 0
## 步数最多加几档
@export var steps_max_bonus: int = 2
## 本局累计搜索次数（含正在搜的这一次）每这么多次加一档，0 = 不算
@export var searches_per_tier: int = 0
## 搜索次数最多加几档
@export var searches_max_bonus: int = 1


## 想要的档位。[param depth] 0 = 最外、1 = 最内。
## [param exploration] 是探索度 `{"steps": 总步数, "searches": 累计搜索次数}`，生成时的敌人传空
func wanted(node: MapNode, depth: float, difficulty: int, scale_id: StringName, exploration: Dictionary = {}) -> int:
	var s := roundi(lerpf(float(by_depth.x), float(by_depth.y), clampf(depth, 0.0, 1.0)))
	s += node.danger * danger_bonus
	s += int(type_bonus.get(String(node.type), 0))
	s += maxi(0, difficulty) * difficulty_bonus
	s += int(by_scale.get(String(scale_id), 0))
	s += exploration_bonus(exploration)
	return maxi(0, s)


## 探索度加几档：步数与搜索次数各自按每 N 加一档、各有上限
func exploration_bonus(exploration: Dictionary) -> int:
	var bonus := 0
	if steps_per_tier > 0:
		bonus += mini(steps_max_bonus, int(exploration.get("steps", 0)) / steps_per_tier)
	if searches_per_tier > 0:
		bonus += mini(searches_max_bonus, int(exploration.get("searches", 0)) / searches_per_tier)
	return maxi(0, bonus)
