## 生成猎手时怎么选战败结果档（134，构件，登记在 [RunRegistry.HUNTER_LOSS_PICKS]）。
## 加一种选法（按段位、按难度、按地图规则……）= 一个子类、登记一行
@abstract
class_name HunterLossPick
extends Resource

## 从 [param options] 里选一档，返回下标；没得选返回 -1。随机数用 [param sys] 的猎手流
@abstract func pick(options: Array[HunterLossOption], sys: HunterSystem) -> int

func describe() -> String:
	return ""
