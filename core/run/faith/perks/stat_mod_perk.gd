## 信仰级的属性修饰（093：自然 1 级开战回血加成、大地 1 级耐力上限、日神 3 级武器耐力减耗……）：
## 把 [member mods] 施加到基线（target = baseline）或每件参战道具（target = items，可按标签筛）
class_name StatModPerk
extends FaithPerk

## "baseline" = 玩家基线（生命 / 耐力上限、回血……）；"items" = 每件参战道具的属性
@export var target: String = "baseline"
## target = items 时只给带这个标签的（空 = 全部）
@export var item_tag: StringName = &""
@export var mods: Array[StatModifier] = []


func compile_into(input: CompileInput, _board: GridInventory, _run: RunState) -> void:
	if target == "baseline":
		# 105：生命上限在第 9 步才算，所以改完基线不用再手工补 spec.max_hp
		input.baseline_mods.append_array(mods)
		return
	var scope := ScopedMod.new()
	if item_tag != &"":
		scope.tags = [item_tag] as Array[StringName]
	scope.mods = mods.duplicate()
	input.scoped.append(scope)


func _summary() -> String:
	if target == "baseline":
		return UiText.t("perk.at_battle_start") % Glossary.mods_text(mods)
	var where := UiText.t("perk.items_tagged") % Glossary.tag_name(item_tag) if item_tag != &"" else UiText.t("perk.each_item")
	return UiText.t("perk.where_mods") % [where, Glossary.mods_text(mods)]


## 103：给基线或「每件道具」的是通用 buff，进栏；只给带某标签的道具的不进
func battle_note(_run: RunState) -> String:
	return describe() if target == "baseline" or item_tag == &"" else ""
