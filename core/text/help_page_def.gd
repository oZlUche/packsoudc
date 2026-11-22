## 百科的一页机制说明（114，作者定）：「每个词条和行为都有专门的一页」里**手写**的那一类（流程、背包、战斗规则、信仰、地图、局外）。
## 词条页（固定词条、标签、伤害类型、buff、属性……）不写这个，[Encyclopedia] 按定义自动生成。
##
## 走内容管线：`data/authoring/help_pages/*.json` → `data/help_pages/*.tres`。正文走 [TextTemplate]（占位符、样式码、`{item:…}` 上色），
## 出现的词条词在百科里画成链接
class_name HelpPageDef
extends Resource

## 分类（目录里的分组），先后即目录顺序
const CATEGORIES := ["flow", "bag", "combat", "faith", "map", "meta"]
## 分类给人看的名字
const CATEGORY_NAMES := {
	"flow": {"zh": "流程", "en": "Flow"}, "bag": {"zh": "背包", "en": "Inventory"}, "combat": {"zh": "战斗规则", "en": "Combat"},
	"faith": {"zh": "信仰", "en": "Faith"}, "map": {"zh": "地图", "en": "Map"}, "meta": {"zh": "局外", "en": "Outside the run"},
}

@export var id: StringName = &""
## 页标题
@export var display_name: String = ""
## 别的语言的标题，`{"en": "..."}`
@export var display_names: Dictionary = {}
## 分类：[constant CATEGORIES] 之一
@export var category: StringName = &"flow"
## 分类里的先后（小的在前）
@export var order: int = 0
## 正文（多行；占位符与样式码照用，不写阿拉伯数字 —— 数从定义里读）
@export_multiline var text: String = ""
## 别的语言的正文
@export var texts: Dictionary = {}
## 「相关」：别的页的 id，或词条名（[constant Glossary.TERMS] 的键）
@export var related: Array[String] = []
## 「相关道具」：道具 id（图鉴没点亮的写「？」）
@export var see_items: Array[StringName] = []
## 377：这一页讲的是神、信物、祭坛 —— 万神院到营地之前百科不列（[method GameFlow.visible_help_pages]）
@export var needs_faith: bool = false
## 377：页头的截图（名字；图在 [constant SHOT_DIR]`<语言>/<名字>.png`，中英各一套，`tools/help_shots.gd` 出）
@export var shots: Array[String] = []

const SHOT_DIR := "res://assets/help/shots/"


## 这一页的截图在当前语言下的路径（没有那一语言的图就用中文的）
func shot_paths(lang: String = "") -> Array[String]:
	var l := lang if lang != "" else UiText.lang
	var out: Array[String] = []
	for n in shots:
		var p := "%s%s/%s.png" % [SHOT_DIR, l, n]
		out.append(p if ResourceLoader.exists(p) else "%szh/%s.png" % [SHOT_DIR, n])
	return out


func text_for(lang: String = "") -> String:
	var l := lang if lang != "" else UiText.lang
	var v := String(texts.get(l, ""))
	return v if v != "" else text


## 分类在当前语言下的名字
static func category_name(cat: String) -> String:
	return UiText.pick(CATEGORY_NAMES.get(cat, null), cat)
