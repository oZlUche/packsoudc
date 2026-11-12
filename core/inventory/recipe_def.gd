## 合成配方（084，作者定的第一条：毒药瓶 + 匕首 → 涂毒匕首）。架构文档 15 节第 5 项的落地。
##
## 作者数据，走内容管线：`data/authoring/recipes/*.json` → `data/recipes/*.tres`。一份配方就是「哪两件 → 哪一件」，顺序无关。
## 314 起：拿起一件、拖到能合的另一件上松手，先开确认窗再合（[method CraftingModule.fuse_items]）；不看贴不贴着，也不是松手立刻合。
class_name RecipeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 088：别的语言的名字，`{"en": "Knife"}`；界面用 [method Names.of] 取（当前语言没有就用 display_name）
@export var display_names: Dictionary = {}
## 输入的两件道具 id（顺序无关）
@export var inputs: Array[StringName] = []
## 产物的道具 id
@export var output: StringName = &""
## 279 起的「拼接」标记。310 起必须是 true（导入与内容测试都拦 false）；314 起合成只有一种，这一项只剩兼容旧数据
@export var adjacent: bool = false
## 给界面看的一句（悬浮窗 / 事件文本里引用）
@export var note: String = ""
## 221 F5: note in other languages, {"en": ...}
@export var notes: Dictionary = {}


## 这两件能不能合成本配方
func matches(a: StringName, b: StringName) -> bool:
	if inputs.size() != 2:
		return false
	return (inputs[0] == a and inputs[1] == b) or (inputs[0] == b and inputs[1] == a)


## 资产目录里的全部配方，按文件名排
static func load_all() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	out.assign(ContentPaths.load_typed(ContentPaths.RECIPES, RecipeDef))
	return out


## 在一组配方里找这两件能合成什么；没有返回 null
static func find(recipes: Array, a: StringName, b: StringName) -> RecipeDef:
	for r in recipes:
		var def := r as RecipeDef
		if def != null and def.adjacent and def.matches(a, b):
			return def
	return null
