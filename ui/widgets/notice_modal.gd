## 383：一张居中的小确认窗 —— 压暗底下、石板框、标题、一段话、一排键。食堂「食材不足」和出征第一屏「食物还没确认」共用。
## 加在 [param anchor] 往上最近的 [GameScreen]（找不到就是最上层的 Control）上，点任何一颗键都先关窗再调那颗键的回调
class_name NoticeModal
extends ColorRect

const SHADE := Color(0.04, 0.05, 0.07, 0.6)
const TEXT_W := 520.0

var frame: OverlayFrame = null
var keys: Array[Button] = []


## [param buttons]：[[字, 回调, 是不是主键], ...]
static func open(anchor: Control, title: String, body: String, buttons: Array) -> NoticeModal:
	var host := anchor
	var up: Node = anchor
	while up != null:
		if up is GameScreen:
			host = up as Control
			break
		if up is Control:
			host = up as Control
		up = up.get_parent()
	var m := NoticeModal.new()
	m.name = "NoticeModal"
	m.color = SHADE
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.z_index = 20
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_child(center)
	m.frame = OverlayFrame.new(16)
	m.frame.set_title(title)
	center.add_child(m.frame)
	var col := UiTheme.vbox(18)
	m.frame.content.add_child(col)
	col.add_child(UiTheme.rich_block(TEXT_W, 16, body))
	var row := UiTheme.hbox(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for spec in buttons:
		var cb: Callable = spec[1]
		var press := func() -> void:
			m.close()
			if cb.is_valid():
				cb.call()
		var b := ScrollKey.primary(String(spec[0]), press) if spec.size() > 2 and bool(spec[2]) else ScrollKey.make(String(spec[0]), press)
		m.keys.append(b)
		row.add_child(b)
	host.add_child(m)
	return m


func close() -> void:
	if is_queued_for_deletion():
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


## 按字找键（测试用）
func key(text: String) -> Button:
	for b in keys:
		if b.text == text:
			return b
	return null
