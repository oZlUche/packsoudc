## 按权重随机选一档（默认的选法）。权重全为 0 时等概率
class_name LossPickRandom
extends HunterLossPick


func pick(options: Array[HunterLossOption], sys: HunterSystem) -> int:
	if options.is_empty():
		return -1
	if options.size() == 1:
		return 0     # 只有一档不掷：不动随机数流
	var total := 0.0
	for o in options:
		total += maxf(0.0, (o as HunterLossOption).weight if o != null else 0.0)
	var rng := sys.rng()
	if total <= 0.0:
		return rng.randi_range(0, options.size() - 1)
	var roll := rng.randf() * total
	for i in options.size():
		var w := maxf(0.0, (options[i] as HunterLossOption).weight if options[i] != null else 0.0)
		if roll < w:
			return i
		roll -= w
	return options.size() - 1


func describe() -> String:
	return "按权重随机"
