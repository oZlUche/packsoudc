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
	var what := UiText.t("deed.dmg_both") if count_dealt and count_taken else (UiText.t("deed.dmg_dealt") if count_dealt else UiText.t("deed.dmg_taken"))
	var kind := (UiText.t("deed.dmg_typed") % Glossary.damage_type_name(damage_type)) if damage_type != &"" else UiText.t("deed.dmg_any")
	return what % [kind, TextTemplate.num(multiplier), (UiText.t("deed.cap") % cap) if cap > 0 else ""]


## 257：事 = 造成 / 受到的哪种伤害；所得按百分数写（× 0.2 → +20%），不写算式
func parts() -> Array:
	var what := UiText.t("deed.dmg_both_ev") if count_dealt and count_taken else (UiText.t("deed.dmg_dealt_ev") if count_dealt else UiText.t("deed.dmg_taken_ev"))
	var kind := (UiText.t("deed.dmg_typed") % Glossary.damage_type_name(damage_type)) if damage_type != &"" else UiText.t("deed.dmg_any")
	return [[what % kind, UiText.t("deed.dmg_gain") % [TextTemplate.num(multiplier * 100.0), (UiText.t("deed.cap") % cap) if cap > 0 else ""]]]

