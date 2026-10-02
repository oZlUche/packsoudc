## 造成 / 受到伤害（093 表：蛮神「伤害 × 1」、日神「火焰伤害 × 1」）：打完一场按这一场的账给点 —— 量 × [member multiplier]，
## 可以只认某种伤害类型、只认造成的或只认受到的；[member cap] 是**一场**最多给几点（0 = 不限；作者定：阈值与倍率都可调）
class_name DamageDeed
extends FaithDeed

## 每点伤害给几点信力
@export var multiplier: float = 1.0
## 只认这种伤害类型（fire / physical…）；空 = 全部
@export var damage_type: StringName = &""
@export var count_dealt: bool = true
@export var count_taken: bool = true
## 一场战斗最多给几点；0 = 不限
@export var cap: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"battle":
		return 0
	var total := 0.0
	if count_dealt:
		total += _sum(payload.get("dealt", {}))
	if count_taken:
		total += _sum(payload.get("taken", {}))
	var got := roundi(total * multiplier)
	return mini(got, cap) if cap > 0 else got


func _sum(by_type: Dictionary) -> float:
	var s := 0.0
	for k in by_type:
		if damage_type == &"" or String(k) == String(damage_type):
			s += float(by_type[k])
	return s


func describe() -> String:
	var what := "造成和受到的" if count_dealt and count_taken else ("造成的" if count_dealt else "受到的")
	var kind := ("%s伤害" % Glossary.damage_type_name(damage_type)) if damage_type != &"" else "伤害"
	return "%s%s × %s%s" % [what, kind, TextTemplate.num(multiplier), ("（每场最多 %d）" % cap) if cap > 0 else ""]
