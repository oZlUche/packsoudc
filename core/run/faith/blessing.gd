## 赐福模板（095，作者定）：写在信仰上 —— 哪些道具能被这位神赐福、赐福版长什么样。
## 导入 / 加载时按它**派生**真实的道具定义（id = `<原 id>_<神 id>`，名字加前缀，标签加 `faith` / `faith:<神>` / `blessed`，
## 稀有度 +rarity_up，价值 ×value_mult，按阶 / 激活 / 按信力的功能来自 [member faith_bonuses]）。赐福版不能激活信仰（只有信物能）
class_name Blessing
extends Resource

## 任一命中；空 = 不看标签
@export var tags: Array[StringName] = []
@export var min_cells: int = 0
@export var exact_grade: int = -1
## 只对这几件（写了就不看上面的条件）
@export var items: Array[StringName] = []
## 名字前缀：「蛮神赐福的」
@export var name_prefix: String = "赐福的"
@export var name_prefix_en: String = "Blessed "
## 赐福版多出的标签（faith / faith:<神> / blessed 自动加）
@export var add_tags: Array[StringName] = []
@export var rarity_up: int = 1
@export var value_mult: float = 1.5
## 赐福版的功能（mode：tier 按阶 / active 激活即 / scaled 按信力）
@export var faith_bonuses: Array[FaithBonus] = []


func matches(def: ItemDef) -> bool:
	if def == null:
		return false
	if not items.is_empty():
		return items.has(def.id)
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
	return true
