## 一条属性加成。包体效果、插槽效果、buff 的 mods、套装档位共用它。
##
## 133（作者定）：**一条只做一件事** —— 乘算或加算，一个数。没有乘区：所有乘算相加后乘一次，加算在乘完之后相加（4.3）。
## 「扩大还是缩小」就是 [member amount] 的符号。要「+20% 且 +3」写两条
class_name StatModifier
extends Resource

enum Mode {
	ADD,   ## 加算：终值 + amount（在所有乘算之后，不吃百分比）
	MULT,  ## 乘算：终值 ×（1 + amount%），和别的乘算先相加再乘
}

## 作用于哪项属性，见 [BattleStats]
@export var stat: StringName = &"damage"

## 乘算还是加算
@export var mode: Mode = Mode.ADD

## 乘算 = 百分数（25 = +25%，−10 = −10%）；加算 = 固定值（暴击率这类按小数：0.05 = 5%）
@export var amount: float = 0.0


static func make(p_stat: StringName, p_mode: Mode, p_amount: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.mode = p_mode
	m.amount = p_amount
	return m


func is_mult() -> bool:
	return mode == Mode.MULT


## 施加 [param times] 份到目标属性上。times 为 0 时什么都不做。
func apply_to(target: StatSet, times: int = 1) -> void:
	if times <= 0 or amount == 0.0:
		return
	var value := target.ensure(stat)
	if mode == Mode.MULT:
		value.add_percent_fixed(StatMath.from_float(amount / 100.0) * times)
	else:
		value.add_flat(StatMath.from_float(amount) * times)


## 133：编辑器在字段下面画的一行灰字（[PropertyForm] 的 `editor_hint()` 约定）：这条是乘算还是加算、扩大还是缩小
func editor_hint() -> String:
	var name := Glossary.stat_name(stat)
	if mode == Mode.MULT and BattleStats.additive_only(stat):
		return "%s只收加算（104）—— 导入会报错" % name
	var grow := amount >= 0.0
	var head := "%s · %s" % ["乘算" if mode == Mode.MULT else "加算", "扩大" if grow else "缩小"]
	if amount == 0.0:
		return "%s：数是 0，这条不起作用" % ("乘算" if mode == Mode.MULT else "加算")
	if mode == Mode.MULT:
		var tail := "和别的乘算先相加再乘，加算在乘完之后" if grow else "乘算之和低于 −100% 按 0 算"
		return "%s：%s 终值 ×（1 %s %s%%）；%s" % [head, name, "+" if grow else "−", _num(absf(amount)), tail]
	var tail2 := "；在所有乘算之后加，不吃百分比" if grow else ""
	return "%s：%s 终值 %s%s%s" % [head, name, "+" if grow else "−", _num(absf(amount)), tail2]


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.2f" % v


func _to_string() -> String:
	if amount == 0.0:
		return "%s: 无效果" % stat
	return "%s: %s" % [stat, ("%+.0f%%" % amount) if mode == Mode.MULT else ("%+.1f" % amount)]
