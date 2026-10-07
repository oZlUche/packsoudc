## 地图生成共用的随机小工具（140 M-25）：格阵与环形的类型分配器都按权重抽类型，抽法只有这一份。
class_name MapRng
extends RefCounted


## 按权重抽一个键：总和 → `randf() * total` → 按 [param order] 依次扣减，扣到 ≤ 0 的那个。
## [param order] 是遍历顺序（空 = 字典自己的顺序）；同一种子要同一结果，调用方的顺序不能变 ——
## 格阵按字典插入序，环形按排好序的键。[param exclude] 里的键（按字符串比）不参与。
## 表空或总权重 ≤ 0 时不掷骰，返回 [param fallback]；浮点误差扣不到 0 时返回最后一个参与的键。
static func pick_weighted(weights: Dictionary, rng: RandomNumberGenerator, order: Array = [], exclude: Array = [], fallback: StringName = &"") -> StringName:
	var keys: Array = []
	for k in (order if not order.is_empty() else weights.keys()):
		if not exclude.has(String(k)):
			keys.append(k)
	var total := 0.0
	for k in keys:
		total += float(weights[k])
	if total <= 0.0:
		return fallback
	var roll := rng.randf() * total
	for k in keys:
		roll -= float(weights[k])
		if roll <= 0.0:
			return StringName(String(k))
	return StringName(String(keys[-1]))
