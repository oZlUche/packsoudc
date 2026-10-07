## 固定第几档（从 0 数，超出按最后一档）
class_name LossPickFixed
extends HunterLossPick

@export var index: int = 0


func pick(options: Array[HunterLossOption], _sys: HunterSystem) -> int:
	if options.is_empty():
		return -1
	return clampi(index, 0, options.size() - 1)


func describe() -> String:
	return "固定第 %d 档" % (index + 1)
