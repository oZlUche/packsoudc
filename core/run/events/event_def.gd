## 一个事件（059 的事件层，报告 063）：踩上一个点先看到的那一屏 —— 文字、图像、几个选项，选项决定后续。
##
## 走内容管线：`data/authoring/events/*.json` → `data/events/*.tres`。节点怎么拿到事件见 [NodeRules.events_by_type] 与 [EventPlacer]：
## 生成地图时按 `content_seed` 定进节点内容（`node.content["event"]`），可以被覆盖或替换（作者：不要写死）。
##
## 选项的条件（[EventCondition]）与后果（[EventOutcome]）都是构件、走注册表：加一种条件或后果不改这里、不改导入器。
class_name EventDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
## 091：别的语言的标题，`{"en": "..."}`；事件屏用 [method title_for] 取（当前语言没写就用 title）
@export var titles: Dictionary = {}
## 正文（多行）
@export_multiline var text: String = ""
## 091：别的语言的正文
@export var texts: Dictionary = {}
## 图像路径，占位：没有文件就画一块底色写路径
@export var image: String = ""
@export var options: Array[EventOption] = []
## 196：用哪一屏演这个事件 —— 空 = 通用事件屏（石板、左图右选项）；`rest_camp` = 夜晚营地（选项画成造物，见 RestCampScreen）
@export var scene: StringName = &""

## 196：[member scene] 认得的值
const SCENES: Array[StringName] = [&"", &"rest_camp"]
## 196：营地屏
const SCENE_REST_CAMP := &"rest_camp"


## 当前语言（或指定语言）下的标题；没写回落 title（[method Names.pick]）
func title_for(lang: String = "") -> String:
	return Names.pick(titles, title, lang)


func text_for(lang: String = "") -> String:
	return Names.pick(texts, text, lang)
