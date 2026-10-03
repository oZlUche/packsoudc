## 118：保险箱扩格 —— 每升一级保险箱多 [member cols] 列、[member rows] 行（[member MetaState.safe_bonus]，开局 [method GameFlow.safe_size] 加上）
class_name TechSafeSize
extends TechEffect

## 每级加几列
@export_range(0, 5) var cols: int = 1
## 每级加几行
@export_range(0, 5) var rows: int = 0


func apply(meta: MetaState) -> void:
	if meta != null:
		meta.safe_bonus += Vector2i(cols, rows)


## 读档：已到 [param level] 级时加成就是每级的 × 级数（照定义算，改了数值读档即跟上）
func heal(meta: MetaState, level: int) -> void:
	if meta != null:
		meta.safe_bonus = Vector2i(cols, rows) * level


func describe() -> String:
	return _text(cols, rows)


func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	return "保险箱共 " + _text(cols * level, rows * level)


static func _text(c: int, r: int) -> String:
	var parts: Array[String] = []
	if c != 0:
		parts.append("+%d 列" % c)
	if r != 0:
		parts.append("+%d 行" % r)
	return "、".join(parts) if not parts.is_empty() else "不变"
