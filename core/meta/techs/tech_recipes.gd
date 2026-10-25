## 252：科技解锁铁匠铺配方 —— 配方自己写要哪项科技几级（[member SmithRecipeDef.tech] / [member SmithRecipeDef.tech_level]），
## [Smithy] 直接查 [method TechService.level]，所以这里什么也不派生（120）。只给说明面板说「会打：……」
class_name TechRecipes
extends TechEffect

## 这项科技自己的 id（配方按它挂；导入器查它和所在科技一致）
@export var tech: StringName = &""


func derive(_meta: MetaState, _level: int) -> void:
	pass


func describe() -> String:
	return describe_level(1)


## 到第 k 级新会打的配方产物名（按配方文件名排）
func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	var names: Array[String] = []
	if tech == &"":
		return ""
	for r in SmithRecipeDef.load_all():
		if r.tech == tech and r.tech_level == level:
			names.append(product_name(r))
	if names.is_empty():
		return ""
	return UiText.t("tech.recipes") % UiText.t("tip.list_sep").join(PackedStringArray(names))


## 配方产物的名字（配方写了名字用配方的）
static func product_name(r: SmithRecipeDef) -> String:
	if r.display_name != "":
		return Names.pick(r.display_names, r.display_name)
	var def := ResourceLoader.load(ContentPaths.asset_file("items", String(r.output))) as ItemDef
	return Names.of(def) if def != null else String(r.output)
