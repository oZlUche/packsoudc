## 每局首次置入某种道具（104，狩猎之神「每局首次将一种战利品置入背包，2^稀有度 + 1」）：
## `place_item` 载荷里 first_in_run 为真（这一局头一回把这种道具置入棋盘，[RunState] 按定义 id 记）且带 [member tag]（空 = 不限）。
## 给 [member rarity_pow] ? 2^稀有度 : amount，再加 [member plus]
class_name FirstPlaceDeed
extends FaithDeed

@export var tag: StringName = &""
@export var rarity_pow: bool = false
@export var plus: int = 0


func gain(event: StringName, payload: Dictionary) -> int:
	if event != &"place_item" or not bool(payload.get("first_in_run", false)):
		return 0
	if tag != &"" and not (payload.get("tags", []) as Array).has(String(tag)):
		return 0
	var base := (1 << clampi(int(payload.get("rarity", 0)), 0, 30)) if rarity_pow else amount
	return base + plus


func describe() -> String:
	var plus_text := (" + %d" % plus) if plus != 0 else ""
	if tag != &"":
		if rarity_pow:
			return UiText.t("deed.first_place_pow_tagged") % Glossary.tag_name(tag)     # 作者 2026-10-17：不写公式
		return UiText.t("deed.first_place_tagged") % [Glossary.tag_name(tag), str(amount), plus_text]
	if rarity_pow:
		return UiText.t("deed.first_place_pow")
	return UiText.t("deed.first_place") % [str(amount), plus_text]
