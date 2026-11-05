## 281 §六（作者 2026-11-05 12:36：所有章默认都有三档）：机关沙漏的一档规模 —— 每半边几层、几格宽、倒计时。
## 开局屏按 [method MapSource.scale_options] 列出来挑；[method HourglassMapConfig.apply_scale] 把它套到配置上
class_name HourglassScale
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字，`{"en": "Small"}`
@export var display_names: Dictionary = {}
## 每半边几层
@export var half_rows: int = 4
## 每半边几格宽
@export var width: int = 5
## 这一档的覆盖要求（类型 → 最远几步内得有一个），盖在规则的 coverage 上；空 = 照规则。图大了中间深的那段长，休息点够不着就放宽
@export var coverage: Dictionary = {}
## 这一档的全局倒计时；0 = 用章节的 step_limit
@export var step_limit: int = 0
## 这一档的带入预算；0 = 用章节的 carry_budget
@export var carry_budget: int = 0
