## 从身上挑一件（8-3 的「失去道具」[LoseItem] 与侵蚀的「损坏道具」[ErodeDamageItem] 同一套挑法）：随机 / 最值钱 / 最不值钱。
## 候选是 `{"inst": ItemInstance, "from": ItemContainer}`，挑中的由调用方从 `from` 里拿走。
## 随机那一档恰好掷一次 `randi_range`（带种子的回归按它对）
class_name ItemPick
extends RefCounted

enum Mode { RANDOM, MOST_VALUABLE, LEAST_VALUABLE }


## 这些容器里的每一件当候选；[param include_bags] = false 时不要包（包没了里面的东西全散）
static func candidates(containers: Array, include_bags: bool) -> Array:
	var out: Array = []
	for c in containers:
		for inst in (c as ItemContainer).items():
			if include_bags or not (inst as ItemInstance).def.is_bag:
				out.append({"inst": inst, "from": c})
	return out


## 按挑法挑一件；候选空返回空字典。[param mode] 是 [enum Mode]（调用方自己的挑法枚举前三档与它对齐）；
## 不认识的挑法取第一件；RANDOM 时 rng 为 null 也取第一件
static func choose(cands: Array, mode: int, rng: RandomNumberGenerator) -> Dictionary:
	if cands.is_empty():
		return {}
	var chosen: Dictionary = cands[0]
	match mode:
		Mode.RANDOM:
			chosen = cands[rng.randi_range(0, cands.size() - 1)] if rng != null else cands[0]
		Mode.MOST_VALUABLE:
			for c in cands:
				if ItemValue.of((c["inst"] as ItemInstance).def) > ItemValue.of((chosen["inst"] as ItemInstance).def):
					chosen = c
		Mode.LEAST_VALUABLE:
			for c in cands:
				if ItemValue.of((c["inst"] as ItemInstance).def) < ItemValue.of((chosen["inst"] as ItemInstance).def):
					chosen = c
	return chosen
