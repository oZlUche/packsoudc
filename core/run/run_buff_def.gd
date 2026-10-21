## 一个 buff（059 的 buff 骨架）：局外的（跨局，由局外选项决定）或一局里的（地图 buff，事件的后果给），同一套构件、不同的生命周期。
##
## 能改什么全在三个列表里，和套装档位（[SetTier]）同一种分法：`mods` 编译期并入战斗属性，`rules` 是带扳机的战斗规则，
## `effects` 是跨域效果 —— 掉落（[LootEffect]）与一局的规则（[RunEffect]：体力上限、开局钱、多搜几次、商店价、幸运）。
## 什么都不带、只有 `tags` 的就是一个**标记**，事件选项的条件查它。
##
## 走内容管线：`data/authoring/run_buffs/*.json` → `data/run_buffs/*.tres`。
## 与 4.5 的 [BuffDef] 不是一回事：那个是战斗内的、每场重置。
class_name RunBuffDef
extends Resource

enum Scope { META, MAP }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## 局外的还是一局里的
@export var scope: Scope = Scope.MAP
## 地图 buff 走几步失效，0 = 整局；局外的忽略（作者：做成字段）
@export var duration_steps: int = 0
## 标记：事件选项的条件查它
@export var tags: Array[StringName] = []
## 战斗属性（编译时并入，和套装同一条路）
@export var mods: Array[StatModifier] = []
## 战斗规则（同上）
@export var rules: Array[AbilityRule] = []
## 跨域效果：LootEffect / RunEffect
@export var effects: Array[Effect] = []


func is_meta() -> bool:
	return scope == Scope.META


func is_map() -> bool:
	return scope == Scope.MAP


func effects_in(p_scope: StringName) -> Array[Effect]:
	var out: Array[Effect] = []
	for e in effects:
		if e != null and (e as Effect).scope() == p_scope:
			out.append(e)
	return out


## 给人看的一行：效果的说明连起来
func summary() -> String:
	var parts: Array[String] = []
	for e in effects:
		if e != null and (e as Effect).describe() != "":
			parts.append((e as Effect).describe())
	if not mods.is_empty():
		parts.append(Glossary.mods_text(mods))
	for r in rules:
		if r != null and Glossary.rule_text(r) != "":
			parts.append(Glossary.rule_text(r))
	return UiText.t("faith.perk_sep").join(parts) if not parts.is_empty() else Names.description_of(self)
