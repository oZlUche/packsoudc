## 一套套装的定义。
##
## [b]效果写在这里，不写在物品上。[/b] 物品只用 [member ItemDef.set_id] 标明归属，
## 它身上显示的套装信息纯粹是 UI 提示（按激活状态做暗／亮切换），不参与结算。
class_name ItemSetDef
extends Resource

enum CountMode {
	INSTANCES,      ## 每件实例算一件：带两把同样的剑 = 2 件
	DISTINCT_DEFS,  ## 同一定义只算一次：逼玩家集齐不同部件
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var count_mode: CountMode = CountMode.DISTINCT_DEFS

## 按 pieces 升序。档位**累加**而非互斥：4 件套同享 2 件档与 4 件档。
## 想要互斥就把高档数值写成增量，不为此增加机制。
@export var tiers: Array[SetTier] = []


func is_valid() -> bool:
	return id != &""


## 达到 count 件时生效的所有档位
func active_tiers(count: int) -> Array[SetTier]:
	var out: Array[SetTier] = []
	for tier in tiers:
		if count >= (tier as SetTier).pieces:
			out.append(tier)
	return out


## 下一个尚未达成的档位需要几件；已全部达成返回 -1。UI 显示「3/4」用它。
func next_threshold(count: int) -> int:
	var best := -1
	for tier in tiers:
		var need := (tier as SetTier).pieces
		if count < need and (best < 0 or need < best):
			best = need
	return best
