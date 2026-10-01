## 献祭品的一条规矩（093，作者表）：满足它的道具献到神坛上换信力。**一件道具满足几条就结算几次**（作者定）。
## 值 = 2^稀有度 × [member multiplier]（× 格子数，若 [member per_cell]）。条件用标签与体积表达：任一标签命中、格子数 ≥ min_cells、体积恰好某档、
## 104：显式写了某条战斗属性（[member has_stat]，技巧之神「带有暴击属性的道具」）。条件之间是「且」
class_name OfferingRule
extends Resource

## 任一命中即可；空 = 不看标签
@export var tags: Array[StringName] = []
## 格子数下限（0 = 不限）：「大及以上」写 9
@export var min_cells: int = 0
## 体积恰好这一档（ItemVolume.Grade；-1 = 不限）：「正好为中」写 2
@export var exact_grade: int = -1
## 104：道具的 `combat.base_stats` 里**显式写了**这条属性才算（默认值不算「带有」：人人都有 10% 暴击率）；空 = 不看
@export var has_stat: StringName = &""
## 稀有度换算之后再乘它（104：默认 1，作者表）
@export var multiplier: float = 1.0
## 再乘格子数（大地之神：稀有度 × 格子数）
@export var per_cell: bool = false
## 给界面的一句（空就按字段拼）
@export var note: String = ""


func matches(def: ItemDef) -> bool:
	if def == null:
		return false
	if not tags.is_empty():
		var hit := false
		for t in tags:
			if def.tags.has(t):
				hit = true
				break
		if not hit:
			return false
	var cells := ItemVolume.cells_of(def)
	if min_cells > 0 and cells < min_cells:
		return false
	if exact_grade >= 0 and ItemVolume.grade_of_cells(cells) != exact_grade:
		return false
	if has_stat != &"" and (def.combat == null or not def.combat.base_stats.has(String(has_stat))):
		return false
	return true


## 这条给多少信力（不匹配 0）
func value(def: ItemDef) -> int:
	if not matches(def):
		return 0
	var base := pow(2.0, float(maxi(0, def.rarity))) * multiplier
	if per_cell:
		base *= float(ItemVolume.cells_of(def))
	return maxi(0, roundi(base))


func describe() -> String:
	if note != "":
		return note
	var parts: Array[String] = []
	if not tags.is_empty():
		var names: Array[String] = []
		for t in tags:
			names.append(Glossary.tag_name(t))
		parts.append("、".join(names))
	if min_cells > 0:
		parts.append("%s体积及以上" % ItemVolume.grade_name(ItemVolume.grade_of_cells(min_cells)))
	if exact_grade >= 0:
		parts.append("体积正好为%s" % ItemVolume.grade_name(exact_grade))
	if has_stat != &"":
		parts.append("带有%s属性" % Glossary.stat_name(has_stat))
	return "%s（2^稀有度 × %.2g%s）" % ["；".join(parts) if not parts.is_empty() else "任何道具", multiplier, " × 格子数" if per_cell else ""]
