## 150：倒计时「剩 / 总」，有按时关的撤离点就跟一句；颜色随剩余变（过半琥珀、四分之一以下或剩五步以内红）。
## 这一章没有倒计时就不显示。地图上那个撤离点的关闭标记仍由地图屏画
extends HudWidget

var _box: StyleBoxFlat


func _init() -> void:
	super()
	_box = StyleBoxFlat.new()
	_box.bg_color = UiPalette.PANEL
	_box.border_color = UiPalette.STAMINA
	_box.set_border_width_all(2)
	_box.set_content_margin_all(6)
	add_theme_stylebox_override("panel", _box)     # 121 特例：边框色随倒计时实时改（见 _paint），得是这一块自己的底（从地图屏搬来，数量不增）


func title() -> String:
	return "倒计时"


func watch() -> Array[Signal]:
	return [run.stepped, run.phase_changed] as Array[Signal]


func text_of() -> String:
	var cd := CountdownModule.of(run)
	if cd == null or not cd.has_countdown():
		return ""
	var left := cd.left()
	var text := "倒计时 %d / %d" % [left, cd.limit()]
	var closing := cd.closing_extract_id()
	if closing >= 0:
		var node := run.map.get_node(closing)
		text += "　　限时撤离点%s" % ["已关闭" if cd.extract_closed(node) else "剩 %d 步关闭" % (left - PaidExtracts.closes_at(node))]
	return text


## 现在该用的颜色（测试读它）


func color() -> Color:
	var cd := CountdownModule.of(run) if run != null else null
	if cd == null or not cd.has_countdown():
		return UiPalette.FG
	var left := cd.left()
	var ratio := float(left) / float(maxi(cd.limit(), 1))
	return UiPalette.HP if (ratio <= 0.25 or left <= 5) else (UiPalette.STAMINA if ratio <= 0.5 else UiPalette.FG)


func _paint() -> void:
	var col := color()
	_text.add_theme_color_override("font_color", col)     # 121 特例：颜色随剩余回合实时变，不是固定样式（从地图屏搬来，数量不增）
	_box.border_color = col
