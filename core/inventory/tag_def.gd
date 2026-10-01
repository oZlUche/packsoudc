## 标签的定义（096，作者定）：道具 / 敌人身上的标签（`weapon` / `metal` / `fire`……）不再只是一个字符串 ——
## 它的名字、别的语言的名字和一句说明都是**数据**，走内容管线（`data/authoring/tags/*.json` → `data/tags/*.tres`）。
##
## 为什么是数据而不是 [Glossary] 里的一张表：标签是 MOD 作者随手加的东西（道具上写一个新词就有了），名字与说明得跟着内容走、
## 能在编辑器里改、能加语言（`display_names["en"]`，和道具名的 [Names.of] 同一条路）。代码里只剩 id。
## 没登记的标签照样能用（导入时只是提醒），界面上显示原词。
class_name TagDef
extends Resource

## 标签本身（道具 `tags` 里写的那个词）。`faith:<id>` 这类动态标签不在这里登记
@export var id: StringName = &""
## 中文名（作者写的原文）
@export var display_name: String = ""
## 别的语言的名字，`{"en": "Weapon"}`；界面用 [method Names.of] 取
@export var display_names: Dictionary = {}
## 一句说明（悬浮窗的词条侧窗用）。空 = 没有词条
@export_multiline var description: String = ""
## 别的语言的说明，`{"en": "..."}`；[method Names.description_of] 取
@export var descriptions: Dictionary = {}
