## 146：规则构件库里的一份 —— 一个填好数值、起了名字的扳机 / 节奏 / 消耗与检查 / 效果。
##
## 作者在构件编辑器里建，规则里写 `"@<id>"` 引用；导入时**复制一份**进规则并打上 `part_ref`（运行时就是普通对象）。
## 四类各一个字段、只能填一个：表单和导入导出按反射就认得，不用为「一个字段装四种基类」另写一套。
class_name RulePartDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 其他语言的名字（键：语言码）
@export var display_names: Dictionary = {}
@export var trigger: Trigger
@export var cadence: Cadence
## 消耗与检查（`*Condition` 就是检查）
@export var cost: Cost
@export var effect: CombatEffect

## 字段名 → 规则里接它的基类。规则里引用时按基类核对（扳机不能填进效果）
const SLOTS := {"trigger": &"Trigger", "cadence": &"Cadence", "cost": &"Cost", "effect": &"CombatEffect"}
## 规则对象上记「这份来自库里的哪一件」的元数据键
const REF_META := &"part_ref"


## 填了的那一个（没填 / 填了多个时返回第一个）
func part() -> Resource:
	for key in SLOTS:
		var v = get(key)
		if v != null:
			return v
	return null


## 它接在规则的哪一类上（`&"Trigger"` …）；没填为空
func root() -> StringName:
	for key in SLOTS:
		if get(key) != null:
			return SLOTS[key]
	return &""


## 填了几个（导入器要求正好一个）
func filled() -> int:
	var n := 0
	for key in SLOTS:
		if get(key) != null:
			n += 1
	return n


## 一句预览（编辑器下拉与列表用）
func preview() -> String:
	var p := part()
	if p == null:
		return ""
	if p is Trigger:
		return Glossary.trigger_text(p)
	if p is CooldownCadence:
		return "每 %.1f 秒" % (p as CooldownCadence).seconds
	if p is Cadence:
		return FieldText.type_label(ContentSchema.registry_name_of(p))
	if p is Cost:
		return (p as Cost).describe()
	return Glossary.effects_text([p])
