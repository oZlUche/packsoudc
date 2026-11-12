## 251：铁匠铺的一张配方 —— 仓库里的几样素材（各几件）+ 一笔钱 → 一件武器 / 防具。和 114 的 [RecipeDef]（局内两件贴着点锤合、无钱无数量）是两回事。
##
## 作者数据，走内容管线：`data/authoring/smith_recipes/*.json` → `data/smith_recipes/*.tres`。表是占位，作者改 json
class_name SmithRecipeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字，`{"en": "..."}`；空 = 用产物的名字
@export var display_names: Dictionary = {}
## 产物的道具 id（得是武器 / 防具 / 盾 / 插件）
@export var output: StringName = &""
## 要的素材：道具 id → 件数
@export var inputs: Dictionary = {}
## 279：按材质类认的素材：材质（[member ItemDef.material]）→ 最低稀有度，每类一件。仓库里任何这类、稀有度够的素材都行
## （`{"bone": 1}` = 一件绿或更高的骨材）；和 [member inputs] 一起要。
## 279 第二批：键也可以是 `crystal:<元素家族>`（[member ItemDef.crystal_family]）—— 那一族够档的魔晶石都行（`{"crystal:fire": 3}` = 火焰魔晶石起）
@export var material_inputs: Dictionary = {}
## 310（改造 C 批，方案 §5.1）：带件数的材料格，一格一条 `{"material": 材质或 crystal:<家族>, "min": 最低稀有度, "count": 件数}`。
## 同一类可以写两格不同的门槛（帝国佩剑「金属 ≥金 ×1 + 金属 ≥紫 ×1」）。写了它的配方出件**固定品质 0**（高档材料只满足资格）。
## 和 [member material_inputs]（一类一件）一起要；界面与扣料都走 [method slots]
@export var material_slots: Array[Dictionary] = []
## 要的钱
@export var funds: int = 0
## 251 补充一：铁匠铺左列的大类（刀剑 / 斧锤 / 弓 / 法杖 / 盾 / 护甲），导入器必填；252：冶炼 `smelt`（产物是素材）
@export_enum("blade", "hammer", "bow", "staff", "shield", "armor", "smelt") var group: String = ""
## 铁匠铺几级才会打（1 ～ 3）
@export_range(1, 3) var level: int = 1
## 252：要先点出哪项科技才会打（空 = 不要科技）；[member tech_level] = 那项科技要几级
@export var tech: StringName = &""
@export var tech_level: int = 1
## 给界面看的一句
@export var note: String = ""
@export var notes: Dictionary = {}


## 资产目录里的全部配方，按文件名排
static func load_all() -> Array[SmithRecipeDef]:
	var out: Array[SmithRecipeDef] = []
	out.assign(ContentPaths.load_typed(ContentPaths.SMITH_RECIPES, SmithRecipeDef))
	return out


## 251 补充一：左列大类的先后（法杖暂无配方也列着）；252 末尾加冶炼
const GROUPS: Array[String] = ["blade", "hammer", "bow", "staff", "shield", "armor", "smelt"]
## 252：冶炼这一类的产物是素材，不是武器 / 防具
const SMELT := "smelt"


static func find(recipes: Array, p_id: StringName) -> SmithRecipeDef:
	for r in recipes:
		var def := r as SmithRecipeDef
		if def != null and def.id == p_id:
			return def
	return null


## 310：全部材料格，旧的 [member material_inputs] 读作「一件、最低稀有度」排在前（按键排），[member material_slots] 跟在后：
## `[{"material": String, "min": int, "count": int}, ...]`
func slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys: Array = material_inputs.keys()
	Ids.sort(keys)
	for m in keys:
		out.append({"material": String(m), "min": int(material_inputs[m]), "count": 1})
	for raw in material_slots:
		out.append({"material": String(raw.get("material", "")), "min": int(raw.get("min", 0)), "count": int(raw.get("count", 1))})
	return out


## 310：这件能不能顶那一格（[method slots] 里的一条）
static func slot_fits(slot: Dictionary, def: ItemDef) -> bool:
	if def == null or def.rarity < int(slot.get("min", 0)):
		return false
	var material := String(slot.get("material", ""))
	if is_crystal_key(material):
		return def.tags.has(&"crystal") and String(def.crystal_family) == material.substr(CRYSTAL_PREFIX.length())
	return def.tags.has(&"material") and def.material == material


## 279 第二批：魔晶石那一格的键前缀（后面跟元素家族）
const CRYSTAL_PREFIX := "crystal:"


## 279：[param def] 能不能顶 [member material_inputs] 里 [param material] 那一格（是素材、材质对、稀有度够；
## 魔晶石那一格：是魔晶石、家族对、稀有度够）
func material_fits(material: String, def: ItemDef) -> bool:
	return slot_fits({"material": material, "min": int(material_inputs.get(material, 0))}, def)


static func is_crystal_key(material: String) -> bool:
	return material.begins_with(CRYSTAL_PREFIX) and material.length() > CRYSTAL_PREFIX.length()


## 279：那一格写给人看的名字 —— 材质类用材质名（「骨」），魔晶石用那一族够档里最便宜那颗的名字
func material_name(material: String, items: ItemDatabase) -> String:
	if is_crystal_key(material):
		var d := material_sample(material, items)
		return Names.of(d) if d != null else material
	return ItemMaterials.name_of(StringName(material))


## 279：材质类那一格在道具库里最便宜的一件（仓库里一件都没有时画它的样子）；道具库里也没有 = null
func material_sample(material: String, items: ItemDatabase) -> ItemDef:
	return slot_sample({"material": material, "min": int(material_inputs.get(material, 0))}, items)


## 310：那一格（[method slots] 里的一条）在道具库里最便宜的一件；没有 = null
static func slot_sample(slot: Dictionary, items: ItemDatabase) -> ItemDef:
	var best: ItemDef = null
	if items == null:
		return null
	var ids: Array = items.ids(true)
	Ids.sort(ids)
	for item_id in ids:
		var d := items.get_def(StringName(String(item_id)))
		if slot_fits(slot, d) and (best == null or d.rarity < best.rarity):
			best = d
	return best
