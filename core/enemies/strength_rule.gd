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


## 想要的档位。[param depth] 0 = 最外、1 = 最内
func wanted(node: MapNode, depth: float, difficulty: int, scale_id: StringName) -> int:
	var s := roundi(lerpf(float(by_depth.x), float(by_depth.y), clampf(depth, 0.0, 1.0)))
	s += node.danger * danger_bonus
	s += int(type_bonus.get(String(node.type), 0))
	s += maxi(0, difficulty) * difficulty_bonus
	s += int(by_scale.get(String(scale_id), 0))
	return maxi(0, s)
