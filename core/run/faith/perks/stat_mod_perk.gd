## 信仰级的属性修饰（093：自然 1 级开战回血加成、大地 1 级耐力上限、日神 3 级武器耐力减耗……）：
## 把 [member mods] 施加到基线（target = baseline）或每件参战道具（target = items，可按标签筛）
class_name StatModPerk
extends FaithPerk

## "baseline" = 玩家基线（生命 / 耐力上限、回血……）；"items" = 每件参战道具的属性
@export var target: String = "baseline"
## target = items 时只给带这个标签的（空 = 全部）
@export var item_tag: StringName = &""
@export var mods: Array[StatModifier] = []


func modify_spec(spec: CombatantSpec, board: GridInventory, _run: RunState) -> void:
	if target == "baseline":
		var hp_before := spec.baseline.total_of(BattleStats.MAX_HP)
		for m in mods:
			(m as StatModifier).apply_to(spec.baseline, 1)
		spec.max_hp = maxi(0, spec.max_hp + spec.baseline.total_of(BattleStats.MAX_HP) - hp_before)     # 基线的生命改了，单位的总生命跟着
		return
	for it in spec.items:
		var item := it as CompiledItem
		if item_tag != &"" and board != null:
			var inst := board.get_item(item.source_uid)
			if inst == null or inst.def == null or not inst.def.tags.has(item_tag):
				continue
		for m in mods:
			(m as StatModifier).apply_to(item.stats, 1)


func _summary() -> String:
	if target == "baseline":
		return "开战时%s" % Glossary.mods_text(mods)
	var where := "带「%s」的道具" % Glossary.tag_name(item_tag) if item_tag != &"" else "每件道具"
	return "%s：%s" % [where, Glossary.mods_text(mods)]


## 103：给基线或「每件道具」的是通用 buff，进栏；只给带某标签的道具的不进
func battle_note(_run: RunState) -> String:
	return describe() if target == "baseline" or item_tag == &"" else ""
