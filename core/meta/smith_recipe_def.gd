## 251：铁匠铺的一张配方 —— 仓库里的几样素材（各几件）+ 一笔钱 → 一件武器 / 防具。和 114 的 [RecipeDef]（局内两件拖合、无钱无数量）是两回事。
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
## 要的钱
@export var funds: int = 0
## 251 补充一：铁匠铺左列的大类（刀剑 / 斧锤 / 弓 / 法杖 / 盾 / 护甲），导入器必填
@export_enum("blade", "hammer", "bow", "staff", "shield", "armor") var group: String = ""
## 铁匠铺几级才会打（1 ～ 3）
@export_range(1, 3) var level: int = 1
## 给界面看的一句
@export var note: String = ""
@export var notes: Dictionary = {}


## 资产目录里的全部配方，按文件名排
static func load_all() -> Array[SmithRecipeDef]:
	var out: Array[SmithRecipeDef] = []
	for res in ContentPaths.load_resources(ContentPaths.SMITH_RECIPES):
		if res is SmithRecipeDef:
			out.append(res)
	return out


## 251 补充一：左列大类的先后（法杖暂无配方也列着）
const GROUPS: Array[String] = ["blade", "hammer", "bow", "staff", "shield", "armor"]


static func find(recipes: Array, p_id: StringName) -> SmithRecipeDef:
	for r in recipes:
		var def := r as SmithRecipeDef
		if def != null and def.id == p_id:
			return def
	return null
