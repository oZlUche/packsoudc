## 211（作者定）：一套**写死的道具组合**（「套路」）—— 成套的狠角色，也可以是刻意拉胯的倒霉蛋。
##
## 作者原话：「原本的敌人种类也要增加，并加上不同流派，增加道具组合，甚至可以是糟糕的组合（比如一下子就将耐力用光，或者根本不成套）」。
## 组装时（[method EnemyPlacer.choose_items]）招牌之后按 [member EnemyLoadout.build_chance] 掷一次：掷中就从这一档可用的套路里按权重挑一套当骨架，
## 档位件数剩下的照旧抽。套路名不给玩家看（4.4），只记进内容的 `build` 键。
## 写在 [member EnemyDef.builds] 里（JSON 里是对象数组）。
class_name EnemyBuild
extends Resource

const GOOD := &"good"
const BAD := &"bad"
const QUALITIES: Array[StringName] = [GOOD, BAD]

@export var id: StringName = &""
## 同一档可用的套路之间按它抽
@export var weight: float = 1.0
## 只在这个档位区间出现（含两端）
@export var strength: Vector2i = Vector2i(0, 3)
## good / bad。bad：权重再乘 [member EnemyLoadout.bad_build_mult]（高档再减半），且不补保底武器（「根本不成套」）
@export var quality: StringName = GOOD
## 除招牌以外的骨架，可重复
@export var items: Array[StringName] = []
## 这套的件不做自动成组（[method EnemyPlacer.auto_groups] 跳过），摆成散件 —— 「学徒把晶石放错了地方」
@export var loose: bool = false
## 给作者 / 测试看的一句话，不进游戏
@export var note: String = ""


func is_bad() -> bool:
	return quality == BAD


func fits(p_strength: int) -> bool:
	return p_strength >= strength.x and p_strength <= strength.y
