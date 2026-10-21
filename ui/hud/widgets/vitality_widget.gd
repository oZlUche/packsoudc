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


## 这一刻画几颗、几颗是红的
func hearts() -> Vector2i:
	return Vector2i(run.vitality.maximum, run.vitality.current) if run != null else Vector2i.ZERO


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
	tooltip_text = _text.text
	var g := grid()
	var s := heart_size()
	var box := get_theme_stylebox("panel") if has_theme_stylebox("panel") else null
	custom_minimum_size = Vector2(g.x * s + maxi(0, g.x - 1) * HEART_GAP, g.y * s + maxi(0, g.y - 1) * HEART_GAP) \
		+ (box.get_minimum_size() if box != null else Vector2.ZERO)     # 自定最小尺寸是连底框边距在内的


func _draw() -> void:
	super()
	var h := hearts()
	var s := heart_size()
	var margin := get_theme_stylebox("panel").get_offset() if has_theme_stylebox("panel") else Vector2.ZERO
	for i in h.x:
		var at := margin + Vector2(i % PER_ROW, floori(float(i) / PER_ROW)) * (s + HEART_GAP)
		UiPalette.draw_heart(self, at, s, UiPalette.HP if i < h.y else UiPalette.HEART_LOST)     # 161：和开局屏角色卡同一颗心
