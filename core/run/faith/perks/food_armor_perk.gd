## 自然 3 级（093）：开战时按棋盘上食物的数量与稀有度给护甲：每件 base + per_rarity × 稀有度
class_name FoodArmorPerk
extends FaithPerk

@export var food_tag: StringName = &"food"
@export var base: float = 2.0
@export var per_rarity: float = 2.0


func compile_into(input: CompileInput, board: GridInventory, _run: RunState) -> void:
	if board == null:
		return
	var total := 0.0
	for inst in board.items():
		var it := inst as ItemInstance
		if it.def != null and it.def.tags.has(food_tag) and not board.acts_as_bag(it.def):
			total += base + per_rarity * float(it.def.rarity)
	if total > 0.0:
		var m := StatModifier.new()
		m.stat = BattleStats.MAX_ARMOR
		m.amount = total
		input.baseline_mods.append(m)


func _summary() -> String:
	return "开战时每件食物给 %.0f 点护甲，越稀有越多（每档 +%.0f）" % [base, per_rarity]


## 103：作用于角色本身 → 进 buff 栏
func battle_note(_run: RunState) -> String:
	return describe()
