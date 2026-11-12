## 150：体力。补 4（作者定）：画成 N 颗心 —— 上限几点就几颗，前「当前」颗红、其余黑（掉一点体力就黑一颗）。
## 上限变了（科技、章节加成、149 的百分比）颗数跟着变；一行放不下（[constant PER_ROW]）折成两行。
## 大档大心、小档小心；停上去的提示仍写「体力 当前 / 上限」（[method text_of]，测试也读它）
extends HudWidget

## 一行最多几颗
const PER_ROW := 10
## 一颗心多大（小档 / 大档）与心之间的空
const HEART_SMALL := 14.0
const HEART_LARGE := 28.0
const HEART_GAP := 3.0


func _init() -> void:
	super()
	_text.visible = false     # 字只用来做提示与测试，画的是心


func title() -> String:
	return "体力"


func watch() -> Array[Signal]:
	return [run.vitality.changed] as Array[Signal]


func text_of() -> String:
	return UiText.t("hud.vitality") % [run.vitality.current, run.vitality.maximum]


func _idle_mouse_filter() -> Control.MouseFilter:
	return Control.MOUSE_FILTER_STOP     # 停上去看提示


## 这一刻画几颗、几颗是红的（上次刷时记下的 —— 231 补充二：顶栏按住时不跟着变）
func hearts() -> Vector2i:
	return _hearts


var _hearts := Vector2i.ZERO


func heart_size() -> float:
	match tier:
		Tier.LARGE:
			return HEART_LARGE
		Tier.DOUBLE:
			return HEART_SMALL * 2.0
	return HEART_SMALL


## 心排成几行几列
func grid() -> Vector2i:
	var n := hearts().x
	return Vector2i(mini(n, PER_ROW), ceili(float(n) / PER_ROW)) if n > 0 else Vector2i.ZERO


func _paint() -> void:
	# 作者 11-12：打输扣的那几颗等劈心动画落下来才变黑（[member HeartBreak.owed]）
	_hearts = Vector2i(run.vitality.maximum, mini(run.vitality.maximum, run.vitality.current + HeartBreak.owed)) if run != null else Vector2i.ZERO
	tooltip_text = _text.text
	var g := grid()
	var s := heart_size()
	var box := get_theme_stylebox("panel") if has_theme_stylebox("panel") else null
	custom_minimum_size = Vector2(g.x * s + maxi(0, g.x - 1) * HEART_GAP, g.y * s + maxi(0, g.y - 1) * HEART_GAP) \
		+ (box.get_minimum_size() if box != null else Vector2.ZERO)     # 自定最小尺寸是连底框边距在内的


## 第 [param i] 颗心的框（屏幕坐标；劈心动画落在这儿）
func heart_rect(i: int) -> Rect2:
	var s := heart_size()
	var xf := get_global_transform()
	return Rect2(xf * _heart_at(i), xf.basis_xform(Vector2(s, s)))


func _heart_at(i: int) -> Vector2:
	var margin := get_theme_stylebox("panel").get_offset() if has_theme_stylebox("panel") else Vector2.ZERO
	return margin + Vector2(i % PER_ROW, floori(float(i) / PER_ROW)) * (heart_size() + HEART_GAP)


func _draw() -> void:
	super()
	var h := hearts()
	var s := heart_size()
	for i in h.x:
		var at := _heart_at(i)
		UiPalette.draw_heart(self, at, s, UiPalette.HP if i < h.y else UiPalette.HEART_LOST)     # 161：和开局屏角色卡同一颗心
