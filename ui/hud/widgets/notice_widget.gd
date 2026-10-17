## 186（作者 2026-10-17：内部说明不给玩家看）：地图顶端栏正下方居中的「提示行」—— 玩家唯一看得到的回话。
##
## 两类话走它：拒绝（「那里走不过去」「这里不是撤离点」「钱不够：撤离要 N 币」）与要紧的局内提示（倒计时、撤离点关闭、侵蚀、动静）。
## 来一句显示 [constant SHOW_SEC] 秒再 [constant FADE_SEC] 秒淡掉，要紧的 [constant URGENT_SEC] 秒、红字；最多叠 [constant MAX_LINES] 行，
## 新的在下，再来一句最上面那句立刻走。没有底板，字按地图纸的深浅取色（浅纸墨字、深纸亮字），外加一圈纸色描边压在线稿上也看得清。
## 不接鼠标、不占地图的边（[method takes_space]）
extends HudWidget

const SHOW_SEC := 3.0
const URGENT_SEC := 5.0
const FADE_SEC := 0.4
const MAX_LINES := 2
const FONT_SIZE := 16
const OUTLINE := 2

## 一行一条：{"label": Label, "left": 还剩几秒（含淡出）, "urgent": bool}
var _lines: Array[Dictionary] = []
var _col: VBoxContainer


func _init() -> void:
	super()
	theme_type_variation = UiTheme.PANEL_BARE     # 没有底板：字直接写在地图纸上（字色、描边写在每行的 LabelSettings 里，不贴主题覆写）
	UiTheme.apply_tone(self, UiTheme.PANEL_BARE)
	_text.visible = false
	_col = UiTheme.vbox(2)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_col)
	set_process(true)


func title() -> String:
	return "提示"


func takes_space() -> bool:
	return false


## 现在写着的几句（拼成一串：宿主按「有没有字」决定显隐）
func text_of() -> String:
	return "\n".join(lines())


func lines() -> Array[String]:
	var out: Array[String] = []
	for l in _lines:
		out.append((l["label"] as Label).text)
	return out


## 最新的一句（测试看）；没有空串
func current() -> String:
	return "" if _lines.is_empty() else (_lines[-1]["label"] as Label).text


func is_urgent() -> bool:
	return not _lines.is_empty() and bool(_lines[-1]["urgent"])


## 写一句。同一句还挂着就只把它的时间重置
func push(text: String, urgent: bool = false) -> void:
	if text == "":
		return
	for l in _lines:
		if (l["label"] as Label).text == text:
			l["left"] = (URGENT_SEC if urgent else SHOW_SEC) + FADE_SEC
			_paint_line(l)
			return
	while _lines.size() >= MAX_LINES:
		_drop(0)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.label_settings = LabelSettings.new()
	label.label_settings.font = UiPalette.cjk_font()
	label.label_settings.font_size = FONT_SIZE
	label.label_settings.outline_size = OUTLINE * 2
	var l := {"label": label, "left": (URGENT_SEC if urgent else SHOW_SEC) + FADE_SEC, "urgent": urgent}
	_col.add_child(label)
	_lines.append(l)
	_paint_line(l)
	refresh()


## 地图纸的深浅：浅纸墨字、深纸亮字（没有底图 = 深）
func paper_tone() -> StringName:
	if run == null or run.chapter == null:
		return UiTheme.TONE_DARK
	return MapSkin.tone(run.chapter.map_skin) if MapSkin.texture(run.chapter.map_skin) != null else UiTheme.TONE_DARK


## 这一句的字色（测试看）
func color_of(urgent: bool) -> Color:
	var tone := paper_tone()
	if urgent:
		return UiPalette.for_tone(UiPalette.HP, tone)
	return UiTheme.INK_DEFAULT if tone == UiTheme.TONE_LIGHT else UiPalette.FG


func _paint_line(l: Dictionary) -> void:
	var label: Label = l["label"]
	var light := paper_tone() == UiTheme.TONE_LIGHT
	label.label_settings.font_color = color_of(bool(l["urgent"]))
	label.label_settings.outline_color = Color(0.93, 0.89, 0.8, 0.85) if light else Color(0, 0, 0, 0.75)
	label.modulate.a = 1.0


## 走时间（测试直接喂）：到点的淡掉、走完的拿走
func step(delta: float) -> void:
	if _lines.is_empty():
		return
	var i := 0
	while i < _lines.size():
		var l := _lines[i]
		l["left"] = float(l["left"]) - delta
		if float(l["left"]) <= 0.0:
			_drop(i)
			continue
		(l["label"] as Label).modulate.a = clampf(float(l["left"]) / FADE_SEC, 0.0, 1.0)
		i += 1


func _process(delta: float) -> void:
	step(delta)


func _drop(i: int) -> void:
	var label: Label = _lines[i]["label"]
	_lines.remove_at(i)
	_col.remove_child(label)
	label.queue_free()
	refresh()
	reset_size()
