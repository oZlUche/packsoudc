## 226 批一（作者 16:32「去掉所有界面里的裸露文字」）：全游戏一种「回话」载体 —— 告示层。
## 一句一卷（[NoticeScroll]），顶端栏下方居中往下叠（间距 [constant GAP]），显示 [constant SHOW_SEC] 秒（要紧的 [constant URGENT_SEC] 秒）再收卷；
## 最多 [constant MAX_LINES] 卷，再来一句最老的那卷立刻收。同一句还挂着就只把它的时间重置。不接鼠标。
## [GameDirector] 造一层盖在所有屏之上（[method set_current]）；没有导演（单测里单独造的屏）时由 [method GameScreen.notice_layer] 在屏上自己挂一层。
## 186 的地图提示行、各屏本地的回话行（商店、神坛、科技、仓库、保险箱、铸炉、出售、开局、读档）、腰带飘字都改走这里
class_name NoticeLayer
extends Control

const SHOW_SEC := 3.0
const URGENT_SEC := 5.0
const MAX_LINES := 2
const GAP := 6.0
## 卷顶离屏顶（顶端栏下面；没有顶端栏的屏同一处）
const TOP := 78.0

static var _current: NoticeLayer = null

## 动效开不开（宿主按 [method UiMotion.enabled] 设）
var motion := false
## 一卷一条：{"scroll": NoticeScroll, "left": 还剩几秒, "urgent": bool}
var _lines: Array[Dictionary] = []
var _col: VBoxContainer


static func current() -> NoticeLayer:
	return _current if is_instance_valid(_current) else null


static func set_current(layer: NoticeLayer) -> void:
	_current = layer


## 往 [param from] 所在的那一层写一句：导演的那层，没有就找最近的屏自己挂的那层；都没有不写
## （233 复测：卷数上限跟着那一屏走 —— 屏有 `notice_cap()` 就照它）
static func post(from: Node, text: String, urgent: bool = false) -> void:
	var n := from
	while n != null and not n.has_method("notice_layer"):
		n = n.get_parent()
	var layer := current()
	if layer == null:
		layer = n.call("notice_layer") if n != null else null
	if layer != null:
		layer.push(text, urgent, int(n.call("notice_cap")) if n != null and n.has_method("notice_cap") else MAX_LINES,
			float(n.call("notice_beside")) if n != null and n.has_method("notice_beside") else 0.0)


func _init() -> void:
	name = "NoticeLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_col = UiTheme.vbox(int(GAP))
	_col.name = "Scrolls"
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.anchor_left = 0.5
	_col.anchor_right = 0.5
	_col.offset_top = TOP
	_col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_col)
	set_process(true)


func _exit_tree() -> void:
	if _current == self:
		_current = null


## 写一句（[param urgent] = 要紧：朱红卷、停得久）。[param cap] 是这一次最多留几卷（233 复测：帐篷屏只留一卷，第二卷会压住窗顶的布招牌）；
## [param beside] > 0 = 卷不居中、从屏中线往右这么远起排（神坛碑顶正对着卷的位置，v4.02 复测）
func push(text: String, urgent: bool = false, cap: int = MAX_LINES, beside: float = 0.0) -> void:
	if text == "":
		return
	_place(beside)
	for l in _lines:
		if (l["scroll"] as NoticeScroll).text == text:
			l["left"] = URGENT_SEC if urgent else SHOW_SEC
			return
	while _lines.size() >= maxi(1, cap):
		_drop(0)
	var s := NoticeScroll.make(text, urgent)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(s)
	_lines.append({"scroll": s, "left": URGENT_SEC if urgent else SHOW_SEC, "urgent": urgent})
	s.open(motion)
	visible = true


## 现在挂着的几句（老的在前）
func lines() -> Array[String]:
	var out: Array[String] = []
	for l in _lines:
		out.append((l["scroll"] as NoticeScroll).text)
	return out


## 最新的一句；没有空串
func current_text() -> String:
	return "" if _lines.is_empty() else (_lines[-1]["scroll"] as NoticeScroll).text


func is_urgent() -> bool:
	return not _lines.is_empty() and bool(_lines[-1]["urgent"])


## 现在挂着的卷（测试看）
func scrolls() -> Array[NoticeScroll]:
	var out: Array[NoticeScroll] = []
	for l in _lines:
		out.append(l["scroll"])
	return out


## 走时间（测试直接喂）：到点的收卷
func step(delta: float) -> void:
	var i := 0
	while i < _lines.size():
		_lines[i]["left"] = float(_lines[i]["left"]) - delta
		if float(_lines[i]["left"]) <= 0.0:
			_drop(i)
			continue
		i += 1


func _process(delta: float) -> void:
	step(delta)


## 拿走第 [param i] 卷：收卷完了再释放（关着动效当场释放）
func _drop(i: int) -> void:
	var s: NoticeScroll = _lines[i]["scroll"]
	_lines.remove_at(i)
	s.close(motion and s.is_inside_tree(), func():
		if is_instance_valid(s):
			s.queue_free())
	if not motion and is_instance_valid(s) and s.get_parent() == _col:
		_col.remove_child(s)     # 关着动效：立刻离开排版（下一句马上顶上来）


## 卷排在哪：[param beside] = 0 居中；> 0 从屏中线往右这么远起排
func _place(beside: float) -> void:
	_col.grow_horizontal = Control.GROW_DIRECTION_END if beside > 0.0 else Control.GROW_DIRECTION_BOTH
	_col.offset_left = maxf(0.0, beside)
	_col.offset_right = maxf(0.0, beside)
