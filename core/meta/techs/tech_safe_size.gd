## 118：保险箱扩格 —— 每升一级保险箱多 [member cols] 列、[member rows] 行（[member MetaState.safe_bonus]，开局 [method GameFlow.safe_size] 加上）
class_name TechSafeSize
extends TechEffect

## 每级加几列
@export_range(0, 5) var cols: int = 1
## 每级加几行
@export_range(0, 5) var rows: int = 0


## 120：到 [param level] 级 = 每级的格子 × 级数
func derive(meta: MetaState, level: int) -> void:
	if meta != null:
		meta.safe_bonus = Vector2i(cols, rows) * maxi(0, level)


func describe() -> String:
	return _text(cols, rows)


func describe_level(level: int, _buff_defs: Dictionary = {}) -> String:
	return UiText.t("tech.safe_total") % _text(cols * level, rows * level)


static func _text(c: int, r: int) -> String:
	var parts: Array[String] = []
	if c != 0:
		parts.append(UiText.t("tech.safe_cols") % c)
	if r != 0:
		parts.append(UiText.t("tech.safe_rows") % r)
	return UiText.t("hud.buff_sep").join(parts) if not parts.is_empty() else UiText.t("tech.safe_unchanged")
