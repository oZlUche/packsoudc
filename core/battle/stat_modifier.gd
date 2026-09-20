## 一条属性加成。包体效果与插槽效果共用它。
##
## 一条 modifier 可以同时给乘区和固定值 —— 两者走 4.3 公式的不同位置，
## 乘区参与连乘，固定值在所有乘法之后相加。
class_name StatModifier
extends Resource

## 作用于哪项属性，见 [BattleStats]
@export var stat: StringName = &"damage"

## 乘区分类，见 [enum StatMath.Buff]。负数表示本条不加乘区。
@export var mult_category: int = -1

## 每份加成给该乘区加多少百分比
@export var mult_percent: int = 0

## 每份加成给固定值加多少（写成浮点便于在编辑器里配，运行时转定点）
@export var flat: float = 0.0


## 施加 [param times] 份到目标属性上。times 为 0 时什么都不做。
func apply_to(target: StatSet, times: int = 1) -> void:
	if times <= 0:
		return
	var value := target.ensure(stat)
	if mult_category >= 0 and mult_percent != 0:
		value.add_mult(mult_category, StatMath.from_percent(mult_percent) * times)
	if flat != 0.0:
		value.add_flat(StatMath.from_float(flat) * times)


func _to_string() -> String:
	var parts: Array[String] = []
	if mult_category >= 0 and mult_percent != 0:
		parts.append("%s %+d%%" % [StatMath.category_name(mult_category), mult_percent])
	if flat != 0.0:
		parts.append("%+.1f" % flat)
	return "%s: %s" % [stat, "，".join(parts) if not parts.is_empty() else "无效果"]
