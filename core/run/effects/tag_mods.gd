## 256（马库斯「操练」）：一局里，带这些标签的参战道具都吃这几条修饰 —— 战斗侧走 105 的按件入口 [ScopedMod]
## （[member RunContext.scoped] → `CompileInput.scoped`），和信仰的 `stat_mod(items, tag)` 同一条路
class_name TagMods
extends RunEffect

## 任一命中（[method ItemDef.has_tag] 的标签）；空 = 所有参战道具
@export var tags: Array[StringName] = []
@export var mods: Array[StatModifier] = []


func modify(ctx: RunContext) -> void:
	if mods.is_empty():
		return
	var scope := ScopedMod.new()
	scope.tags = tags.duplicate()
	scope.mods = mods.duplicate()
	ctx.scoped.append(scope)


func describe() -> String:
	return UiText.t("bonus.tag_mods") % [_tags_text(tags), Glossary.mods_text(mods)]


static func _tags_text(p_tags: Array[StringName]) -> String:
	if p_tags.is_empty():
		return UiText.t("perk.each_item")
	return UiText.t("bonus.tag_sep").join(p_tags.map(func(t: StringName) -> String: return Glossary.tag_name(t)))
