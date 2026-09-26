## 合成配方（084，作者定的第一条：毒药瓶 + 匕首 → 涂毒匕首）。架构文档 15 节第 5 项的落地。
##
## 作者数据，走内容管线：`data/authoring/recipes/*.json` → `data/recipes/*.tres`。一份配方就是「哪两件 → 哪一件」，顺序无关。
## **相邻即合**（087 作者定）：两件在棋盘上四邻相接，走到下一个点时自动合成（[method RunState.craft_pairs] / `resolve_crafts`）；
## 产物落在 uid 小的那件的位置上，放不下试另一件的位置、再自动找位，再放不下进暂存区并提醒。没有「拖到一起」「配对」这一步。
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
## 给界面看的一句（悬浮窗 / 事件文本里引用）
@export var note: String = ""


## 这两件能不能合成本配方
func matches(a: StringName, b: StringName) -> bool:
	if inputs.size() != 2:
		return false
	return (inputs[0] == a and inputs[1] == b) or (inputs[0] == b and inputs[1] == a)


## 资产目录里的全部配方，按文件名排
static func load_all() -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	var dir := DirAccess.open(ContentPaths.RECIPES)
	if dir == null:
		return out
	var names: Array[String] = []
	for f in dir.get_files():
		var n := f.trim_suffix(".remap")
		if n.ends_with(".tres") or n.ends_with(".res"):
			names.append(n)
	names.sort()
	for n in names:
		var res := load(ContentPaths.RECIPES + "/" + n)
		if res is RecipeDef:
			out.append(res)
	return out


## 在一组配方里找这两件能合成什么；没有返回 null
static func find(recipes: Array, a: StringName, b: StringName) -> RecipeDef:
	for r in recipes:
		var def := r as RecipeDef
		if def != null and def.matches(a, b):
			return def
	return null
